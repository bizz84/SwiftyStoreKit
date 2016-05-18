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
        func addProduct(product: SKProduct) {
            if let productIdentifier = product._productIdentifier {
                products[productIdentifier] = product
            }
        }
        func allProductsMatching(productIds: Set<String>) -> Set<SKProduct>? {
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
    #if os(iOS)
    private var receiptRefreshRequest: InAppReceiptRefreshRequest?
    #endif
    // MARK: Enums
    public struct RetrieveResults {
        public let retrievedProducts: Set<SKProduct>
        public let invalidProductIDs: Set<String>
        public let error: NSError?
    }

    public enum PurchaseError {
        case Failed(error: NSError)
        case InvalidProductId(productId: String)
        case NoProductIdentifier
        case PaymentNotAllowed
    }
    public enum PurchaseResult {
        case Success(productId: String)
        case Error(error: PurchaseError)
    }
    public struct RestoreResults {
        public let restoredProductIds: [String]
        public let restoreFailedProducts: [(ErrorType, String?)]
    }
    public enum RefreshReceiptResult {
        case Success
        case Error(error: ErrorType)
    }
    public struct CompletedTransaction {
        public let productId: String
        public let transactionState: PaymentTransactionState
    }

    public enum InternalErrorCode: Int {
        case RestoredPurchaseWhenPurchasing = 0
        case PurchasedWhenRestoringPurchase = 1
    }

    // MARK: Singleton
    private static let sharedInstance = SwiftyStoreKit()
    
    public class var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    class var hasInFlightPayments: Bool {
        return sharedInstance.inflightPurchases.count > 0 || sharedInstance.restoreRequest != nil
    }
    
    public class func completeTransactions(completion: (completedTransactions: [CompletedTransaction]) -> ()) {
        sharedInstance.completeTransactionsObserver = InAppCompleteTransactionsObserver(callback: completion)
    }
    
    // MARK: Public methods
    public class func retrieveProductsInfo(productIds: Set<String>, completion: (result: RetrieveResults) -> ()) {
        
        guard let products = sharedInstance.store.allProductsMatching(productIds) else {
            
            sharedInstance.requestProducts(productIds, completion: completion)
            return
        }
        completion(result: RetrieveResults(retrievedProducts: products, invalidProductIDs: [], error: nil))
    }
    
    public class func purchaseProduct(productId: String, completion: (result: PurchaseResult) -> ()) {
        
        if let product = sharedInstance.store.products[productId] {
            sharedInstance.purchase(product: product, completion: completion)
        }
        else {
            retrieveProductsInfo(Set([productId])) { result -> () in
                if let product = result.retrievedProducts.first {
                    sharedInstance.purchase(product: product, completion: completion)
                }
                else if let error = result.error {
                    completion(result: .Error(error: .Failed(error: error)))
                }
                else if let invalidProductId = result.invalidProductIDs.first {
                    completion(result: .Error(error: .InvalidProductId(productId: invalidProductId)))
                }
            }
        }
    }
    
    public class func restorePurchases(completion: (results: RestoreResults) -> ()) {

        sharedInstance.restoreRequest = InAppProductPurchaseRequest.restorePurchases() { results in
        
            sharedInstance.restoreRequest = nil
            let results = sharedInstance.processRestoreResults(results)
            completion(results: results)
        }
    }

    /**
     *  Verify application receipt
     *  - Parameter receiptVerifyURL: receipt verify url (default: Test)
     *  - Parameter password: Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).
     *  - Parameter session: the session used to make remote call.
     *  - Parameter completion: handler for result
     */
    public class func verifyReceipt(
        receiptVerifyURL url: ReceiptVerifyURL = .Test,
        password: String? = nil,
        session: NSURLSession = NSURLSession.sharedSession(),
        completion:(result: VerifyReceiptResult) -> ()) {
            InAppReceipt.verify(receiptVerifyURL: url, password: password, session: session, completion: completion)
    }
  
    /**
     *  Verify the purchase of a product in a receipt
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to test in
     *  - Parameter validUntil: the expires date of the subscription must be valid until this date. If nil, no verification
     */
    public class func verifyPurchase(
        productId productId: String,
        inReceipt receipt: ReceiptInfo,
        validUntil: NSDate? = nil
    ) -> SwiftyStoreKit.VerifyPurchaseResult {
        return InAppReceipt.verifyPurchase(productId: productId, inReceipt: receipt, validUntil: validUntil)
    }

    #if os(iOS) || os(tvOS)
    // After verifying receive and have `ReceiptError.NoReceiptData`, refresh receipt using this method
    public class func refreshReceipt(receiptProperties: [String : AnyObject]? = nil, completion: (result: RefreshReceiptResult) -> ()) {
        sharedInstance.receiptRefreshRequest = InAppReceiptRefreshRequest.refresh(receiptProperties) { result in

            sharedInstance.receiptRefreshRequest = nil

            switch result {
            case .Success:
                if InAppReceipt.data == nil {
                    completion(result: .Error(error: ReceiptError.NoReceiptData))
                } else {
                    completion(result: .Success)
                }
            case .Error(let e):
                completion(result: .Error(error: e))
            }
        }
    }
    #elseif os(OSX)
     // Call exit with a status of 173. This exit status notifies the system that your application has determined that its receipt is invalid. At this point, the system attempts to obtain a valid receipt and may prompt for the user’s iTunes credentials
    public class func refreshReceipt() {
         exit(ReceiptExitCode.NotValid.rawValue)
    }
    #endif

    // MARK: private methods
    private func purchase(product product: SKProduct, completion: (result: PurchaseResult) -> ()) {
        guard SwiftyStoreKit.canMakePayments else {
            completion(result: .Error(error: .PaymentNotAllowed))
            return
        }
        guard let productIdentifier = product._productIdentifier else {
            completion(result: .Error(error: .NoProductIdentifier))
            return
        }

        inflightPurchases[productIdentifier] = InAppProductPurchaseRequest.startPayment(product) { results in

            self.inflightPurchases[productIdentifier] = nil
            
            if let purchasedProductTransaction = results.first {
                let returnValue = self.processPurchaseResult(purchasedProductTransaction)
                completion(result: returnValue)
            }
        }
    }

    private func processPurchaseResult(result: InAppProductPurchaseRequest.TransactionResult) -> PurchaseResult {
        switch result {
        case .Purchased(let productId):
            return .Success(productId: productId)
        case .Failed(let error):
            return .Error(error: .Failed(error: error))
        case .Restored(let productId):
            return .Error(error: .Failed(error: storeInternalError(code: InternalErrorCode.RestoredPurchaseWhenPurchasing.rawValue, description: "Cannot restore product \(productId) from purchase path")))
        }
    }
    
    private func processRestoreResults(results: [InAppProductPurchaseRequest.TransactionResult]) -> RestoreResults {
        var restoredProductIds: [String] = []
        var restoreFailedProducts: [(ErrorType, String?)] = []
        for result in results {
            switch result {
            case .Purchased(let productId):
                restoreFailedProducts.append((storeInternalError(code: InternalErrorCode.PurchasedWhenRestoringPurchase.rawValue, description: "Cannot purchase product \(productId) from restore purchases path"), productId))
            case .Failed(let error):
                restoreFailedProducts.append((error, nil))
            case .Restored(let productId):
                restoredProductIds.append(productId)
            }
        }
        return RestoreResults(restoredProductIds: restoredProductIds, restoreFailedProducts: restoreFailedProducts)
    }
    
    private func requestProducts(productIds: Set<String>, completion: (result: RetrieveResults) -> ()) {
        
        inflightQueries[productIds] = InAppProductQueryRequest.startQuery(productIds) { result in
        
            self.inflightQueries[productIds] = nil
            for product in result.retrievedProducts {
                self.store.addProduct(product)
            }
            completion(result: result)
        }
    }
    
    private func storeInternalError(code code: Int = 0, description: String = "") -> NSError {
        return NSError(domain: "SwiftyStoreKit", code: code, userInfo: [ NSLocalizedDescriptionKey: description ])
    }
}
