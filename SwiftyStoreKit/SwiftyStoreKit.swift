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

    private let productsInfoController: ProductsInfoController

    private let paymentQueueController: PaymentQueueController

    private var receiptRefreshRequest: InAppReceiptRefreshRequest?

    init(productsInfoController: ProductsInfoController = ProductsInfoController(),
         paymentQueueController: PaymentQueueController = PaymentQueueController(paymentQueue: SKPaymentQueue.default())) {

        self.productsInfoController = productsInfoController
        self.paymentQueueController = paymentQueueController
    }

    // MARK: Internal methods

    func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) {
        return productsInfoController.retrieveProductsInfo(productIds, completion: completion)
    }

    func purchaseProduct(_ productId: String, atomically: Bool = true, applicationUsername: String = "", completion: @escaping ( PurchaseResult) -> Void) {

        if let product = productsInfoController.products[productId] {
            purchase(product: product, atomically: atomically, applicationUsername: applicationUsername, completion: completion)
        } else {
            retrieveProductsInfo(Set([productId])) { result -> Void in
                if let product = result.retrievedProducts.first {
                    self.purchase(product: product, atomically: atomically, applicationUsername: applicationUsername, completion: completion)
                } else if let error = result.error {
                    completion(.error(error: SKError(_nsError: error as NSError)))
                } else if let invalidProductId = result.invalidProductIDs.first {
                    let userInfo = [ NSLocalizedDescriptionKey: "Invalid product id: \(invalidProductId)" ]
                    let error = NSError(domain: SKErrorDomain, code: SKError.paymentInvalid.rawValue, userInfo: userInfo)
                    completion(.error(error: SKError(_nsError: error)))
                }
            }
        }
    }

    func restorePurchases(atomically: Bool = true, applicationUsername: String = "", completion: @escaping (RestoreResults) -> Void) {

        paymentQueueController.restorePurchases(RestorePurchases(atomically: atomically, applicationUsername: applicationUsername) { results in

            let results = self.processRestoreResults(results)
            completion(results)
        })
    }

    func completeTransactions(atomically: Bool = true, completion: @escaping ([Product]) -> Void) {

        paymentQueueController.completeTransactions(CompleteTransactions(atomically: atomically, callback: completion))
    }

    func finishTransaction(_ transaction: PaymentTransaction) {

        paymentQueueController.finishTransaction(transaction)
    }

    func refreshReceipt(_ receiptProperties: [String : Any]? = nil, completion: @escaping (RefreshReceiptResult) -> Void) {
        receiptRefreshRequest = InAppReceiptRefreshRequest.refresh(receiptProperties) { result in

            self.receiptRefreshRequest = nil

            switch result {
            case .success:
                if let appStoreReceiptData = InAppReceipt.appStoreReceiptData {
                    completion(.success(receiptData: appStoreReceiptData))
                } else {
                    completion(.error(error: ReceiptError.noReceiptData))
                }
            case .error(let e):
                completion(.error(error: e))
            }
        }
    }

    // MARK: private methods
    private func purchase(product: SKProduct, atomically: Bool, applicationUsername: String = "", completion: @escaping (PurchaseResult) -> Void) {
        guard SwiftyStoreKit.canMakePayments else {
            let error = NSError(domain: SKErrorDomain, code: SKError.paymentNotAllowed.rawValue, userInfo: nil)
            completion(.error(error: SKError(_nsError: error)))
            return
        }

        paymentQueueController.startPayment(Payment(product: product, atomically: atomically, applicationUsername: applicationUsername) { result in

            completion(self.processPurchaseResult(result))
        })
    }

    private func processPurchaseResult(_ result: TransactionResult) -> PurchaseResult {
        switch result {
        case .purchased(let product):
            return .success(product: product)
        case .failed(let error):
            return .error(error: error)
        case .restored(let product):
            return .error(error: storeInternalError(description: "Cannot restore product \(product.productId) from purchase path"))
        }
    }

    private func processRestoreResults(_ results: [TransactionResult]) -> RestoreResults {
        var restoredProducts: [Product] = []
        var restoreFailedProducts: [(SKError, String?)] = []
        for result in results {
            switch result {
            case .purchased(let product):
                let error = storeInternalError(description: "Cannot purchase product \(product.productId) from restore purchases path")
                restoreFailedProducts.append((error, product.productId))
            case .failed(let error):
                restoreFailedProducts.append((error, nil))
            case .restored(let product):
                restoredProducts.append(product)
            }
        }
        return RestoreResults(restoredProducts: restoredProducts, restoreFailedProducts: restoreFailedProducts)
    }

    private func storeInternalError(code: SKError.Code = SKError.unknown, description: String = "") -> SKError {
        let error = NSError(domain: SKErrorDomain, code: code.rawValue, userInfo: [ NSLocalizedDescriptionKey: description ])
        return SKError(_nsError: error)
    }
}

extension SwiftyStoreKit {

    // MARK: Singleton
    private static let sharedInstance = SwiftyStoreKit()

    // MARK: Public methods - Purchases
    public class var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }

    public class func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) {

        return sharedInstance.retrieveProductsInfo(productIds, completion: completion)
    }

    /**
     *  Purchase a product
     *  - Parameter productId: productId as specified in iTunes Connect
     *  - Parameter atomically: whether the product is purchased atomically (e.g. finishTransaction is called immediately)
     *  - Parameter applicationUsername: an opaque identifier for the user’s account on your system
     *  - Parameter completion: handler for result
     */
    public class func purchaseProduct(_ productId: String, atomically: Bool = true, applicationUsername: String = "", completion: @escaping ( PurchaseResult) -> Void) {

        sharedInstance.purchaseProduct(productId, atomically: atomically, applicationUsername: applicationUsername, completion: completion)
    }

    public class func restorePurchases(atomically: Bool = true, applicationUsername: String = "", completion: @escaping (RestoreResults) -> Void) {

        sharedInstance.restorePurchases(atomically: atomically, applicationUsername: applicationUsername, completion: completion)
    }

    public class func completeTransactions(atomically: Bool = true, completion: @escaping ([Product]) -> Void) {

        sharedInstance.completeTransactions(atomically: atomically, completion: completion)
    }

    public class func finishTransaction(_ transaction: PaymentTransaction) {

        sharedInstance.finishTransaction(transaction)
    }

    // After verifying receive and have `ReceiptError.NoReceiptData`, refresh receipt using this method
    public class func refreshReceipt(_ receiptProperties: [String : Any]? = nil, completion: @escaping (RefreshReceiptResult) -> Void) {

        sharedInstance.refreshReceipt(receiptProperties, completion: completion)
    }
}

extension SwiftyStoreKit {

    // MARK: Public methods - Receipt verification

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
        using validator: ReceiptValidator,
        password: String? = nil,
        completion:@escaping (VerifyReceiptResult) -> Void) {

        InAppReceipt.verify(using: validator, password: password) { result in

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /**
     *  Verify the purchase of a Consumable or NonConsumable product in a receipt
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the purchase
     *  - return: either notPurchased or purchased
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
}
