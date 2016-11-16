//
// SwiftyStoreKit.swift
// SwiftyStoreKit
//
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import StoreKit

public class SwiftyStoreKit {

    // MARK: Private declarations
    private class InAppPurchaseStore {
        var products: [String: SKProduct] = [:]
        func addProduct(_ product: SKProduct) {
            if let productIdentifier = product._productIdentifier {
                products[productIdentifier] = product
            }
        }
        func allProductsMatching(_ productIds: Set<String>) -> Set<SKProduct>? {
            var requestedProducts = Set<SKProduct>()
            for productId in productIds {
                guard let product = products[productId] else {
                    return nil
                }
                requestedProducts.insert(product)
            }
            return requestedProducts
        }
    }
    private var store: InAppPurchaseStore = InAppPurchaseStore()

    // As we can have multiple inflight queries and purchases, we store them in a dictionary by product id
    private var inflightQueries: [Set<String>: InAppProductQueryRequest] = [:]
    private var inflightPurchases: [String: InAppProductPurchaseRequest] = [:]
    private var restoreRequest: InAppProductPurchaseRequest?
    private var completeTransactionsObserver: InAppCompleteTransactionsObserver?
    #if os(iOS) || os(tvOS)
    private var receiptRefreshRequest: InAppReceiptRefreshRequest?
    #endif
    
    private enum InternalErrorCode: Int {
        case restoredPurchaseWhenPurchasing = 0
        case purchasedWhenRestoringPurchase = 1
    }

    // MARK: Singleton
    private static let sharedInstance = SwiftyStoreKit()
    
    public class var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    class var hasInFlightPayments: Bool {
        return sharedInstance.inflightPurchases.count > 0 || sharedInstance.restoreRequest != nil
    }
    
    public class func completeTransactions(atomically: Bool = true, completion: @escaping ([Product]) -> ()) {
        sharedInstance.completeTransactionsObserver = InAppCompleteTransactionsObserver(atomically: atomically, callback: completion)
    }
    
    // MARK: Public methods
    public class func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> ()) {
        
        guard let products = sharedInstance.store.allProductsMatching(productIds) else {
            
            sharedInstance.requestProducts(productIds, completion: completion)
            return
        }
        completion(RetrieveResults(retrievedProducts: products, invalidProductIDs: [], error: nil))
    }
    
    /**
     *  Purchase a product
     *  - Parameter productId: productId as specified in iTunes Connect
     *  - Parameter atomically: whether the product is purchased atomically (e.g. finishTransaction is called immediately)
     *  - Parameter applicationUsername: an opaque identifier for the user’s account on your system
     *  - Parameter completion: handler for result
     */
    public class func purchaseProduct(_ productId: String, atomically: Bool = true, applicationUsername: String = "", completion: @escaping ( PurchaseResult) -> ()) {
        
        if let product = sharedInstance.store.products[productId] {
            sharedInstance.purchase(product: product, atomically: atomically, applicationUsername: applicationUsername, completion: completion)
        }
        else {
            retrieveProductsInfo(Set([productId])) { result -> () in
                if let product = result.retrievedProducts.first {
                    sharedInstance.purchase(product: product, atomically: atomically, applicationUsername: applicationUsername, completion: completion)
                }
                else if let error = result.error {
                    completion(.error(error: .failed(error: error)))
                }
                else if let invalidProductId = result.invalidProductIDs.first {
                    completion(.error(error: .invalidProductId(productId: invalidProductId)))
                }
            }
        }
    }
    
    public class func restorePurchases(atomically: Bool = true, completion: @escaping (RestoreResults) -> ()) {

        sharedInstance.restoreRequest = InAppProductPurchaseRequest.restorePurchases(atomically: atomically) { results in
        
            sharedInstance.restoreRequest = nil
            let results = sharedInstance.processRestoreResults(results)
            completion(results)
        }
    }
    
    public class func finishTransaction(_ transaction: PaymentTransaction) {
     
        InAppProductPurchaseRequest.finishTransaction(transaction)
    }

    /**
     * Return receipt data from the application bundle. This is read from Bundle.main.appStoreReceiptURL
     */
    public static var localReceiptData: Data? {
        return InAppReceipt.appStoreReceiptData
    }
    
    /**
     *  Verify application receipt
     *  - Parameter password: Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).
     *  - Parameter session: the session used to make remote call.
     *  - Parameter completion: handler for result
     */
    public class func verifyReceipt(
        password: String? = nil,
        session: URLSession = URLSession.shared,
        completion:@escaping (VerifyReceiptResult) -> ()) {
        InAppReceipt.verify(urlType: .production, password: password, session: session) { result in
         
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
  
    /**
     *  Verify the purchase of a Consumable or NonConsumable product in a receipt
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the purchase
     *  - return: either NotPurchased or Purchased
     */
    public class func verifyPurchase(
        productId: String,
        inReceipt receipt: ReceiptInfo
    ) -> VerifyPurchaseResult {
        return InAppReceipt.verifyPurchase(productId: productId, inReceipt: receipt)
    }
  
    /**
     *  Verify the purchase of a subscription (auto-renewable, free or non-renewing) in a receipt. This method extracts all transactions mathing the given productId and sorts them by date in descending order, then compares the first transaction expiry date against the validUntil value.
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the subscription
     *  - Parameter validUntil: date to check against the expiry date of the subscription. If nil, no verification
     *  - Parameter validDuration: the duration of the subscription. Only required for non-renewable subscription.
     *  - return: either NotPurchased or Purchased / Expired with the expiry date found in the receipt
     */
    public class func verifySubscription(
        productId: String,
        inReceipt receipt: ReceiptInfo,
        validUntil date: Date = Date(),
        validDuration duration: TimeInterval? = nil
    ) -> VerifySubscriptionResult {
        return InAppReceipt.verifySubscription(productId: productId, inReceipt: receipt, validUntil: date, validDuration: duration)
    }

    #if os(iOS) || os(tvOS)
    // After verifying receive and have `ReceiptError.NoReceiptData`, refresh receipt using this method
    public class func refreshReceipt(_ receiptProperties: [String : AnyObject]? = nil, completion: @escaping (RefreshReceiptResult) -> ()) {
        sharedInstance.receiptRefreshRequest = InAppReceiptRefreshRequest.refresh(receiptProperties) { result in

            sharedInstance.receiptRefreshRequest = nil

            switch result {
            case .success:
                if let appStoreReceiptData = InAppReceipt.appStoreReceiptData {
                    completion(.success(receiptData: appStoreReceiptData))
                }
                else {
                    completion(.error(error: ReceiptError.noReceiptData))
                }
            case .error(let e):
                completion(.error(error: e))
            }
        }
    }
    #elseif os(OSX)
     // Call exit with a status of 173. This exit status notifies the system that your application has determined that its receipt is invalid. At this point, the system attempts to obtain a valid receipt and may prompt for the user’s iTunes credentials
    public class func refreshReceipt() {
         exit(ReceiptExitCode.notValid.rawValue)
    }
    #endif

    // MARK: private methods
    private func purchase(product: SKProduct, atomically: Bool, applicationUsername: String = "", completion: @escaping (PurchaseResult) -> ()) {
        guard SwiftyStoreKit.canMakePayments else {
            completion(.error(error: .paymentNotAllowed))
            return
        }
        guard let productIdentifier = product._productIdentifier else {
            completion(.error(error: .noProductIdentifier))
            return
        }

        inflightPurchases[productIdentifier] = InAppProductPurchaseRequest.startPayment(product: product, atomically: atomically, applicationUsername: applicationUsername) { results in

            self.inflightPurchases[productIdentifier] = nil
            
            if let purchasedProductTransaction = results.first {
                let returnValue = self.processPurchaseResult(purchasedProductTransaction)
                completion(returnValue)
            }
        }
    }

    private func processPurchaseResult(_ result: InAppProductPurchaseRequest.TransactionResult) -> PurchaseResult {
        switch result {
        case .purchased(let product):
            return .success(product: product)
        case .failed(let error):
            return .error(error: .failed(error: error))
        case .restored(let product):
            return .error(error: .failed(error: storeInternalError(code: InternalErrorCode.restoredPurchaseWhenPurchasing.rawValue, description: "Cannot restore product \(product.productId) from purchase path")))
        }
    }
    
    private func processRestoreResults(_ results: [InAppProductPurchaseRequest.TransactionResult]) -> RestoreResults {
        var restoredProducts: [Product] = []
        var restoreFailedProducts: [(Swift.Error, String?)] = []
        for result in results {
            switch result {
            case .purchased(let product):
                restoreFailedProducts.append((storeInternalError(code: InternalErrorCode.purchasedWhenRestoringPurchase.rawValue, description: "Cannot purchase product \(product.productId) from restore purchases path"), product.productId))
            case .failed(let error):
                restoreFailedProducts.append((error, nil))
            case .restored(let product):
                restoredProducts.append(product)
            }
        }
        return RestoreResults(restoredProducts: restoredProducts, restoreFailedProducts: restoreFailedProducts)
    }
    
    private func requestProducts(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> ()) {
        
        inflightQueries[productIds] = InAppProductQueryRequest.startQuery(productIds) { result in
        
            self.inflightQueries[productIds] = nil
            for product in result.retrievedProducts {
                self.store.addProduct(product)
            }
            completion(result)
        }
    }
    
    private func storeInternalError(code: Int = 0, description: String = "") -> NSError {
        return NSError(domain: "SwiftyStoreKit", code: code, userInfo: [ NSLocalizedDescriptionKey: description ])
    }
}
