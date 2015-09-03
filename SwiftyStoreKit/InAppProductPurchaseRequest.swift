//
//  InAppProductPurchaseRequest.swift
//  WordShooter
//
//  Created by Andrea Bizzotto on 01/09/2015.
//  Copyright © 2015 musevisions. All rights reserved.
//

import UIKit
import StoreKit

public class InAppProductPurchaseRequest: NSObject, SKPaymentTransactionObserver {

    enum ResultType {
        case Purchased(productId: String)
        case Restored(productId: String)
        case NothingToRestore
        case Failed(error: NSError)
    }
    
    typealias RequestCallback = (result: ResultType) -> ()
    private let callback: RequestCallback
    private var purchases : [SKPaymentTransactionState: [String]] = [:]

    var paymentQueue: SKPaymentQueue {
        get {
            return  SKPaymentQueue.defaultQueue()
        }
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
        let payment = SKMutablePayment(product: product)
        dispatch_async(dispatch_get_global_queue(0, 0), {
            self.paymentQueue.addPayment(payment)
        })
    }
    private func startRestorePurchases() {
        
        dispatch_async(dispatch_get_global_queue(0, 0), {
            self.paymentQueue.restoreCompletedTransactions()
        })
    }
    
    // MARK: SKPaymentTransactionObserver
    public func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            switch transaction.transactionState {
            case .Purchased:
                dispatch_async(dispatch_get_main_queue(), {
                    self.callback(result: ResultType.Purchased(productId: transaction.payment.productIdentifier))
                })
                paymentQueue.finishTransaction(transaction)
                break
            case .Failed:
                dispatch_async(dispatch_get_main_queue(), {
                    // It appears that in some edge cases transaction.error is nil here. Since returning an associated error is
                    // mandatory, return a default one if needed
                    let altError = NSError(domain: SKErrorDomain, code: 0, userInfo: [ NSLocalizedDescriptionKey: "Unknown error" ])
                    self.callback(result: ResultType.Failed(error: transaction.error ?? altError))
                })
                paymentQueue.finishTransaction(transaction)
                break
            case .Restored:
                dispatch_async(dispatch_get_main_queue(), {
                    self.callback(result: ResultType.Restored(productId: transaction.payment.productIdentifier))
                })
                paymentQueue.finishTransaction(transaction)
                break
            case .Purchasing:
                // In progress: do nothing
                break
            case .Deferred:
                break
            }
            // Keep track of payments
            if let _ = purchases[transaction.transactionState] {
                purchases[transaction.transactionState]?.append(transaction.payment.productIdentifier)
            }
            else {
                purchases[transaction.transactionState] = [ transaction.payment.productIdentifier ]
            }
        }
    }
    
    public func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    public func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
        
        dispatch_async(dispatch_get_main_queue(), {
            self.callback(result: ResultType.Failed(error: error))
        })
    }

    public func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        
        if let product = self.product {
            self.callback(result: ResultType.Restored(productId: product.productIdentifier))
            return
        }
        // This method will be called after all purchases have been restored (includes the case of no purchases)
        guard let restored = purchases[.Restored] where restored.count > 0 else {
            
            self.callback(result: ResultType.NothingToRestore)
            return
        }
        //print("\(restored)")
    }
    
    public func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }
}

