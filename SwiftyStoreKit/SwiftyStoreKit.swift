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
    }
    private var store: InAppPurchaseStore = InAppPurchaseStore()

    // As we can have multiple inflight queries and purchases, we store them in a dictionary by product id
    private var inflightQueries: [String: InAppProductQueryRequest] = [:]
    private var inflightPurchases: [String: InAppProductPurchaseRequest] = [:]
    private var restoreRequest: InAppProductPurchaseRequest?
    #if os(iOS)
    private var receiptRefreshRequest: InAppReceiptRefreshRequest?
    #endif
    // MARK: Enums
    public enum PurchaseError {
        case Failed(error: ErrorType)
        case NoProductIdentifier
        case PaymentNotAllowed
    }
    public enum PurchaseResult {
        case Success(productId: String)
        case Error(error: PurchaseError)
    }
    public enum RetrieveResult {
        case Success(product: SKProduct)
        case Error(error: ErrorType)
    }
    public struct RestoreResults {
        public let restoredProductIds: [String]
        public let restoreFailedProducts: [(ErrorType, String?)]
    }
    public enum RefreshReceiptResult {
        case Success
        case Error(error: ErrorType)
    }
    public enum InternalErrorCode: Int {
        case RestoredPurchaseWhenPurchasing = 0
        case NothingToRestoreWhenPurchasing = 1
        case PurchasedWhenRestoringPurchase = 2
    }

    // MARK: Singleton
    private static let sharedInstance = SwiftyStoreKit()
    
    public class var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    // MARK: Public methods
    public class func retrieveProductInfo(productId: String, completion: (result: RetrieveResult) -> ()) {
        guard let product = sharedInstance.store.products[productId] else {
            
            sharedInstance.requestProduct(productId) { (inner: () throws -> SKProduct) -> () in
                do {
                    let product = try inner()
                    completion(result: .Success(product: product))
                }
                catch let error {
                    completion(result: .Error(error: error))
                }
            }
            return
        }
        completion(result: .Success(product: product))
    }
    
    public class func purchaseProduct(productId: String, completion: (result: PurchaseResult) -> ()) {
        
        if let product = sharedInstance.store.products[productId] {
            sharedInstance.purchase(product: product, completion: completion)
        }
        else {
            retrieveProductInfo(productId) { (result) -> () in
                if case .Success(let product) = result {
                    sharedInstance.purchase(product: product, completion: completion)
                }
                else if case .Error(let error) = result {
                    completion(result: .Error(error: .Failed(error: error)))
                }
            }
        }
    }
    
    public class func restorePurchases(completion: (results: RestoreResults) -> ()) {

        // Called multiple
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

            if let productIdentifier = product._productIdentifier {
                self.inflightPurchases[productIdentifier] = nil
            }
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
    
    
    // http://appventure.me/2015/06/19/swift-try-catch-asynchronous-closures/
    private func requestProduct(productId: String, completion: (result: (() throws -> SKProduct)) -> ()) -> () {
        
        inflightQueries[productId] = InAppProductQueryRequest.startQuery([productId]) { result in
        
            self.inflightQueries[productId] = nil
            if case .Success(let products) = result {
                
                // Add to Store
                for product in products {
                    //print("Received product with ID: \(product.productIdentifier)")
                    self.store.addProduct(product)
                }
                guard let product = self.store.products[productId] else {
                    completion(result: { throw ResponseError.NoProducts })
                    return
                }
                completion(result: { return product })
            }
            else if case .Error(let error) = result {
                
                completion(result: { throw error })
            }
        }
    }
    
    private func storeInternalError(code code: Int = 0, description: String = "") -> NSError {
        return NSError(domain: "SwiftyStoreKit", code: code, userInfo: [ NSLocalizedDescriptionKey: description ])
    }
}
