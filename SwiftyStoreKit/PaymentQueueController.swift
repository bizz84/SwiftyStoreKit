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

public protocol PaymentQueue: class {

    func add(_ observer: SKPaymentTransactionObserver)
    func remove(_ observer: SKPaymentTransactionObserver)

    func add(_ payment: SKPayment)
    
    func restoreCompletedTransactions()
}

extension SKPaymentQueue: PaymentQueue { }

public class PaymentQueueController: NSObject, SKPaymentTransactionObserver {

    public enum TransactionResult {
        case purchased(product: Product)
        case restored(product: Product)
        case failed(error: Error)
    }
    
    public struct Payment {
        public let product: SKProduct
        public let atomically: Bool
        public let applicationUsername: String
        public let callback: (TransactionResult) -> ()
    }
    
    public struct RestorePurchases {
        let atomically: Bool
        let callback: ([TransactionResult]) -> ()
    }

    unowned let paymentQueue: PaymentQueue

    deinit {
        paymentQueue.remove(self)
    }

    public init(paymentQueue: PaymentQueue = SKPaymentQueue.default()) {
     
        self.paymentQueue = paymentQueue
        super.init()
        paymentQueue.add(self)
    }
    
    public func startPayment(_ payment: Payment) {
        
        let skPayment = SKMutablePayment(product: payment.product)
        skPayment.applicationUsername = payment.applicationUsername
        paymentQueue.add(skPayment)
    }
    
    
    // MARK: SKPaymentTransactionObserver
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {

    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {

    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }

}
