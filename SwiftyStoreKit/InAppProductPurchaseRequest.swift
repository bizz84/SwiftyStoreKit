//
// InAppProductPurchaseRequest.swift
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
import Foundation

class InAppProductPurchaseRequest: NSObject, SKPaymentTransactionObserver {

    enum TransactionResult {
        case purchased(product: Product)
        case restored(product: Product)
        case failed(error: Error)
    }
    
    typealias RequestCallback = ([TransactionResult]) -> ()
    private let callback: RequestCallback
    private var purchases : [SKPaymentTransactionState: [String]] = [:]
    
    var paymentQueue: SKPaymentQueue {
        return SKPaymentQueue.default()
    }
    
    let product : SKProduct?
    let atomically: Bool
    
    deinit {
        paymentQueue.remove(self)
    }
    // Initialiser for product purchase
    private init(product: SKProduct?, atomically: Bool, callback: @escaping RequestCallback) {

        self.atomically = atomically
        self.product = product
        self.callback = callback
        super.init()
        paymentQueue.add(self)
    }
    // MARK: Public methods
    class func startPayment(product: SKProduct, atomically: Bool, applicationUsername: String = "", callback: @escaping RequestCallback) -> InAppProductPurchaseRequest {
        let request = InAppProductPurchaseRequest(product: product, atomically: atomically, callback: callback)
        request.startPayment(product, applicationUsername: applicationUsername)
        return request
    }
    class func restorePurchases(atomically: Bool, callback: @escaping RequestCallback) -> InAppProductPurchaseRequest {
        let request = InAppProductPurchaseRequest(product: nil, atomically: atomically, callback: callback)
        request.startRestorePurchases()
        return request
    }
    
    class func finishTransaction(_ transaction: PaymentTransaction) {
        guard let skTransaction = transaction as? SKPaymentTransaction else {
            print("Object is not a SKPaymentTransaction: \(transaction)")
            return
        }
        SKPaymentQueue.default().finishTransaction(skTransaction)
    }
    
    // MARK: Private methods
    private func startPayment(_ product: SKProduct, applicationUsername: String = "") {
        guard let _ = product._productIdentifier else {
            let error = NSError(domain: SKErrorDomain, code: 0, userInfo: [ NSLocalizedDescriptionKey: "Missing product identifier" ])
            callback([TransactionResult.failed(error: error)])
            return
        }
        let payment = SKMutablePayment(product: product)
        payment.applicationUsername = applicationUsername
        
        DispatchQueue.global(qos: .default).async {
            self.paymentQueue.add(payment)
        }
    }
    private func startRestorePurchases() {
        
        DispatchQueue.global(qos: .default).async {
            self.paymentQueue.restoreCompletedTransactions()
        }
    }
        
    // MARK: SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        var transactionResults: [TransactionResult] = []
        
        for transaction in transactions {
            
            let transactionProductIdentifier = transaction.payment.productIdentifier
            
            var isPurchaseRequest = false
            if let productIdentifier = product?._productIdentifier {
                if transactionProductIdentifier != productIdentifier {
                    continue
                }
                isPurchaseRequest = true
            }

            let transactionState = transaction.transactionState

            switch transactionState {
            case .purchased:
                if isPurchaseRequest {
                    let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !atomically)
                    transactionResults.append(.purchased(product: product))
                    if atomically {
                        paymentQueue.finishTransaction(transaction)
                    }
                }
            case .failed:
                // TODO: How to discriminate between purchase and restore?
                // It appears that in some edge cases transaction.error is nil here. Since returning an associated error is
                // mandatory, return a default one if needed
                let message = "Transaction failed for product ID: \(transactionProductIdentifier)"
                let altError = NSError(domain: SKErrorDomain, code: 0, userInfo: [ NSLocalizedDescriptionKey: message ])
                transactionResults.append(.failed(error: transaction.error ?? altError))
                paymentQueue.finishTransaction(transaction)
            case .restored:
                if !isPurchaseRequest {
                    let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !atomically)
                    transactionResults.append(.restored(product: product))
                    if atomically {
                        paymentQueue.finishTransaction(transaction)
                    }
                }
            case .purchasing:
                // In progress: do nothing
                break
            case .deferred:
                break
            }
            // Keep track of payments
            if let _ = purchases[transactionState] {
                purchases[transactionState]?.append(transactionProductIdentifier)
            }
            else {
                purchases[transactionState] = [ transactionProductIdentifier ]
            }
        }
        if transactionResults.count > 0 {
            DispatchQueue.main.async {
                self.callback(transactionResults)
            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        
        DispatchQueue.main.async {
            self.callback([.failed(error: error)])
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        // This method will be called after all purchases have been restored (includes the case of no purchases)
        guard let restored = purchases[.restored], restored.count > 0 else {
            
            self.callback([])
            return
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }
}

