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
        case Purchased(productId: String)
        case Restored(productId: String)
        case Failed(error: NSError)
    }
    
    typealias RequestCallback = (results: [TransactionResult]) -> ()
    private let callback: RequestCallback
    private var purchases : [PaymentTransactionState: [String]] = [:]

    var paymentQueue: SKPaymentQueue {
        return SKPaymentQueue.defaultQueue()
    }
    
    let product : SKProduct?
    
    deinit {
        paymentQueue.removeTransactionObserver(self)
    }
    // Initialiser for product purchase
    private init(product: SKProduct?, callback: RequestCallback) {

        self.product = product
        self.callback = callback
        super.init()
        paymentQueue.addTransactionObserver(self)
    }
    // MARK: Public methods
    class func startPayment(product: SKProduct, callback: RequestCallback) -> InAppProductPurchaseRequest {
        let request = InAppProductPurchaseRequest(product: product, callback: callback)
        request.startPayment(product)
        return request
    }
    class func restorePurchases(callback: RequestCallback) -> InAppProductPurchaseRequest {
        let request = InAppProductPurchaseRequest(product: nil, callback: callback)
        request.startRestorePurchases()
        return request
    }
    
    // MARK: Private methods
    private func startPayment(product: SKProduct) {
        guard let _ = product._productIdentifier else {
            return
        }
        let payment = SKMutablePayment(product: product)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.paymentQueue.addPayment(payment)
        }
    }
    private func startRestorePurchases() {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.paymentQueue.restoreCompletedTransactions()
        }
    }
    
    // MARK: SKPaymentTransactionObserver
    func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        var transactionResults: [TransactionResult] = []
        
        for transaction in transactions {

            #if os(iOS)
                let transactionState = transaction.transactionState
            #elseif os(OSX)
                let transactionState = PaymentTransactionState(rawValue: transaction.transactionState)!
            #endif

            switch transactionState {
            case .Purchased:
                transactionResults.append(.Purchased(productId: transaction.payment.productIdentifier))
                paymentQueue.finishTransaction(transaction)
            case .Failed:
                // It appears that in some edge cases transaction.error is nil here. Since returning an associated error is
                // mandatory, return a default one if needed
                let altError = NSError(domain: SKErrorDomain, code: 0, userInfo: [ NSLocalizedDescriptionKey: "Unknown error" ])
                transactionResults.append(.Failed(error: transaction.error ?? altError))
                paymentQueue.finishTransaction(transaction)
            case .Restored:
                transactionResults.append(.Restored(productId: transaction.payment.productIdentifier))
                paymentQueue.finishTransaction(transaction)
            case .Purchasing:
                // In progress: do nothing
                break
            case .Deferred:
                break
            }
            // Keep track of payments
            if let _ = purchases[transactionState] {
                purchases[transactionState]?.append(transaction.payment.productIdentifier)
            }
            else {
                purchases[transactionState] = [ transaction.payment.productIdentifier ]
            }
        }
        if transactionResults.count > 0 {
            dispatch_async(dispatch_get_main_queue()) {
                self.callback(results: transactionResults)
            }
        }
    }
    
    func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
        
        dispatch_async(dispatch_get_main_queue()) {
            self.callback(results: [.Failed(error: error)])
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        if let product = self.product, productIdentifier = product._productIdentifier {
            self.callback(results: [.Restored(productId: productIdentifier)])
            return
        }
        // This method will be called after all purchases have been restored (includes the case of no purchases)
        guard let restored = purchases[.Restored] where restored.count > 0 else {
            
            self.callback(results: [])
            return
        }
        //print("\(restored)")
    }
    
    func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }
}

