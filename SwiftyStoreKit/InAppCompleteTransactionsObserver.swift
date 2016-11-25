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

extension SKPaymentTransactionState {
    
    var stringValue: String {
        switch self {
        case .purchasing: return "Purchasing"
        case .purchased: return "Purchased"
        case .failed: return "Failed"
        case .restored: return "Restored"
        case .deferred: return "Deferred"
        }
    }
}

class InAppCompleteTransactionsObserver: NSObject, SKPaymentTransactionObserver {
    
    private var callbackCalled: Bool = false
        
    typealias TransactionsCallback = ([Product]) -> ()
    
    var paymentQueue: SKPaymentQueue {
        return SKPaymentQueue.default()
    }

    let atomically: Bool
    
    deinit {
        paymentQueue.remove(self)
    }

    let callback: TransactionsCallback
    
    init(atomically: Bool, callback: @escaping TransactionsCallback) {
    
        self.atomically = atomically
        self.callback = callback
        super.init()
        paymentQueue.add(self)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        if callbackCalled {
            return
        }
        if SwiftyStoreKit.hasInFlightPayments {
            return
        }
        
        var completedTransactions: [Product] = []
        
        for transaction in transactions {
            
            let transactionState = transaction.transactionState

            if transactionState != .purchasing {
                
                let product = Product(productId: transaction.payment.productIdentifier, transaction: transaction, needsFinishTransaction: !atomically)
                
                completedTransactions.append(product)
                
                print("Finishing transaction for payment \"\(transaction.payment.productIdentifier)\" with state: \(transactionState.stringValue)")
                
                if atomically {
                    paymentQueue.finishTransaction(transaction)
                }
            }
        }
        callbackCalled = true

        callback(completedTransactions)
    }
}
