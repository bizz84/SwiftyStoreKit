//
// InAppCompleteTransactionsObserver.swift
// SwiftyStoreKit
//
// Copyright (c) 2016 Andrea Bizzotto (bizz84@gmail.com)
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

extension PaymentTransactionState {
    
    var stringValue: String {
        switch self {
        case Purchasing: return "Purchasing"
        case Purchased: return "Purchased"
        case Failed: return "Failed"
        case Restored: return "Restored"
        case Deferred: return "Deferred"
        }
    }
}

class InAppCompleteTransactionsObserver: NSObject, SKPaymentTransactionObserver {
    
    private var callbackCalled: Bool = false
        
    typealias TransactionsCallback = (completedTransactions: [SwiftyStoreKit.CompletedTransaction]) -> ()
    
    var paymentQueue: SKPaymentQueue {
        return SKPaymentQueue.defaultQueue()
    }

    deinit {
        paymentQueue.removeTransactionObserver(self)
    }

    let callback: TransactionsCallback
    
    init(callback: TransactionsCallback) {
    
        self.callback = callback
        super.init()
        paymentQueue.addTransactionObserver(self)
    }

    func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        if callbackCalled {
            return
        }
        if SwiftyStoreKit.hasInFlightPayments {
            return
        }
        
        var completedTransactions: [SwiftyStoreKit.CompletedTransaction] = []
        
        for transaction in transactions {
            
            #if os(iOS)
                let transactionState = transaction.transactionState
            #elseif os(OSX)
                let transactionState = PaymentTransactionState(rawValue: transaction.transactionState)!
            #endif

            if transactionState != .Purchasing {
                
                let completedTransaction = SwiftyStoreKit.CompletedTransaction(productId: transaction.payment.productIdentifier, transactionState: transactionState)
                
                completedTransactions.append(completedTransaction)
                
                print("Finishing transaction for payment \"\(transaction.payment.productIdentifier)\" with state: \(transactionState.stringValue)")
                
                paymentQueue.finishTransaction(transaction)
            }
        }
        callbackCalled = true

        callback(completedTransactions: completedTransactions)
    }
}
