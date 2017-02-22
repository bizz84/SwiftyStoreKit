//
// PaymentQueueController.swift
// SwiftyStoreKit
//
// Copyright (c) 2017 Andrea Bizzotto (bizz84@gmail.com)
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

import Foundation
import StoreKit

protocol TransactionController {
    
    /**
     * - param transactions: transactions to process
     * - param paymentQueue: payment queue for finishing transactions
     * - return: array of unhandled transactions
     */
    func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction]
}

public enum TransactionResult {
    case purchased(product: Product)
    case restored(product: Product)
    case failed(error: SKError)
}

public protocol PaymentQueue: class {

    func add(_ observer: SKPaymentTransactionObserver)
    func remove(_ observer: SKPaymentTransactionObserver)

    func add(_ payment: SKPayment)
    
    func restoreCompletedTransactions(withApplicationUsername username: String?)
    
    func finishTransaction(_ transaction: SKPaymentTransaction)
}

extension SKPaymentQueue: PaymentQueue { }

class PaymentQueueController: NSObject, SKPaymentTransactionObserver {
    
    private let paymentsController: PaymentsController
    
    private let restorePurchasesController: RestorePurchasesController
    
    private let completeTransactionsController: CompleteTransactionsController
    
    unowned let paymentQueue: PaymentQueue

    deinit {
        paymentQueue.remove(self)
    }

    init(paymentQueue: PaymentQueue = SKPaymentQueue.default(),
                paymentsController: PaymentsController = PaymentsController(),
                restorePurchasesController: RestorePurchasesController = RestorePurchasesController(),
                completeTransactionsController: CompleteTransactionsController = CompleteTransactionsController()) {
     
        self.paymentQueue = paymentQueue
        self.paymentsController = paymentsController
        self.restorePurchasesController = restorePurchasesController
        self.completeTransactionsController = completeTransactionsController
        super.init()
        paymentQueue.add(self)
    }
    
    func startPayment(_ payment: Payment) {
        
        let skPayment = SKMutablePayment(product: payment.product)
        skPayment.applicationUsername = payment.applicationUsername
        paymentQueue.add(skPayment)
        
        paymentsController.append(payment)
    }
    
    func restorePurchases(_ restorePurchases: RestorePurchases) {
        
        if restorePurchasesController.restorePurchases != nil {
            // return .inProgress
            return
        }
        
        paymentQueue.restoreCompletedTransactions(withApplicationUsername: restorePurchases.applicationUsername)
        
        restorePurchasesController.restorePurchases = restorePurchases
    }
    
    func completeTransactions(_ completeTransactions: CompleteTransactions) {
        
        completeTransactionsController.completeTransactions = completeTransactions
    }
    
    func finishTransaction(_ transaction: PaymentTransaction) {
        guard let skTransaction = transaction as? SKPaymentTransaction else {
            print("Object is not a SKPaymentTransaction: \(transaction)")
            return
        }
        paymentQueue.finishTransaction(skTransaction)
    }

    
    // MARK: SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        /*
         * Some notes about how requests are processed by SKPaymentQueue:
         *
         * SKPaymentQueue is used to queue payments or restore purchases requests.
         * Payments are processed serially and in-order and require user interaction.
         * Restore purchases requests don't require user interaction and can jump ahead of the queue.
         * SKPaymentQueue rejects multiple restore purchases calls.
         * Having one payment queue observer for each request causes extra processing
         * Failed translations only ever belong to queued payment request.
         * restoreCompletedTransactionsFailedWithError is always called when a restore purchases request fails.
         * paymentQueueRestoreCompletedTransactionsFinished is always called following 0 or more update transactions when a restore purchases request succeeds.
         * A complete transactions handler is require to catch any transactions that are updated when the app is not running.
         * Registering a complete transactions handler when the app launches ensures that any pending transactions can be cleared.
         * If a complete transactions handler is missing, pending transactions can be mis-attributed to any new incoming payments or restore purchases.
         * 
         * The order in which transaction updates are processed is:
         * 1. payments (transactionState: .purchased and .failed for matching product identifiers)
         * 2. restore purchases (transactionState: .restored, or restoreCompletedTransactionsFailedWithError, or paymentQueueRestoreCompletedTransactionsFinished)
         * 3. complete transactions (transactionState: .purchased, .failed, .restored, .deferred)
         * Any transactions where state == .purchasing are ignored.
         */
        var unhandledTransactions = paymentsController.processTransactions(transactions, on: paymentQueue)
        
        unhandledTransactions = restorePurchasesController.processTransactions(unhandledTransactions, on: paymentQueue)
        
        unhandledTransactions = completeTransactionsController.processTransactions(unhandledTransactions, on: paymentQueue)
        
        if unhandledTransactions.count > 0 {
            print("unhandledTransactions: \(unhandledTransactions)")
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        
        restorePurchasesController.restoreCompletedTransactionsFailed(withError: error)
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {

        restorePurchasesController.restoreCompletedTransactionsFinished()
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }

}
