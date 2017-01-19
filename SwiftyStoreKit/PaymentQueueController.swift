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


public protocol TransactionController {
    
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
    case failed(error: Error)
}

public protocol PaymentQueue: class {

    func add(_ observer: SKPaymentTransactionObserver)
    func remove(_ observer: SKPaymentTransactionObserver)

    func add(_ payment: SKPayment)
    
    func restoreCompletedTransactions()
    
    func finishTransaction(_ transaction: SKPaymentTransaction)
}

extension SKPaymentQueue: PaymentQueue { }

public class PaymentQueueController: NSObject, SKPaymentTransactionObserver {
    
    private let paymentsController: PaymentsController
    
    private let restorePurchasesController: RestorePurchasesController
    
    private let completeTransactionsController: CompleteTransactionsController
    
    unowned let paymentQueue: PaymentQueue

    deinit {
        paymentQueue.remove(self)
    }

    public init(paymentQueue: PaymentQueue = SKPaymentQueue.default(),
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
    
    public func startPayment(_ payment: Payment) {
        
        if paymentsController.hasPayment(payment) {
            // return .inProgress
            return
        }
        
        let skPayment = SKMutablePayment(product: payment.product)
        skPayment.applicationUsername = payment.applicationUsername
        paymentQueue.add(skPayment)
        
        paymentsController.insert(payment)
    }
    
    public func startRestorePurchases(_ restorePurchases: RestorePurchases) {
        
        if restorePurchasesController.restorePurchases != nil {
            // return .inProgress
            return
        }
        
        paymentQueue.restoreCompletedTransactions()
        
        restorePurchasesController.restorePurchases = restorePurchases
    }
    
    public func completeTransactions(_ completeTransactions: CompleteTransactions) {
        
        completeTransactionsController.completeTransactions = completeTransactions
    }
    
    public func finishTransaction(_ transaction: PaymentTransaction) {
        guard let skTransaction = transaction as? SKPaymentTransaction else {
            print("Object is not a SKPaymentTransaction: \(transaction)")
            return
        }
        paymentQueue.finishTransaction(skTransaction)
    }

    
    // MARK: SKPaymentTransactionObserver
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        /*
        
         The payment queue seems to process payments in-order, however any calls to restorePurchases can easily jump
         ahead of the queue as the user flows for restorePurchases are simpler.
         
         SKPaymentQueue rejects multiple restorePurchases calls
         
         Having one payment queue observer for each request causes extra processing
         
         Can a failed translation ever belong to a restore purchases request?
         No. restoreCompletedTransactionsFailedWithError is called instead.
         
        */
        var unhandledTransactions = paymentsController.processTransactions(transactions, on: paymentQueue)
        
        unhandledTransactions = restorePurchasesController.processTransactions(unhandledTransactions, on: paymentQueue)
        
        unhandledTransactions = completeTransactionsController.processTransactions(unhandledTransactions, on: paymentQueue)
        
        if unhandledTransactions.count > 0 {
            print("unhandledTransactions: \(unhandledTransactions)")
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        
        restorePurchasesController.restoreCompletedTransactionsFailed(withError: error)
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {

        restorePurchasesController.restoreCompletedTransactionsFinished()
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }

}
