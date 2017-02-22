//
// CompleteTransactionsController.swift
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

struct CompleteTransactions {
    let atomically: Bool
    let callback: ([Product]) -> ()
    
    init(atomically: Bool, callback: @escaping ([Product]) -> ()) {
        self.atomically = atomically
        self.callback = callback
    }
}

extension SKPaymentTransactionState {
    
    var stringValue: String {
        switch self {
        case .purchasing: return "purchasing"
        case .purchased: return "purchased"
        case .failed: return "failed"
        case .restored: return "restored"
        case .deferred: return "deferred"
        }
    }
}


class CompleteTransactionsController: TransactionController {

    var completeTransactions: CompleteTransactions?
    
    func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {
        
        guard let completeTransactions = completeTransactions else {
            return transactions
        }

        var unhandledTransactions: [SKPaymentTransaction] = []
        var products: [Product] = []
        
        for transaction in transactions {
            
            let transactionState = transaction.transactionState
            
            if transactionState != .purchasing {
                
                let product = Product(productId: transaction.payment.productIdentifier, transaction: transaction, needsFinishTransaction: !completeTransactions.atomically)
                
                products.append(product)
                
                print("Finishing transaction for payment \"\(transaction.payment.productIdentifier)\" with state: \(transactionState.stringValue)")
                
                if completeTransactions.atomically {
                    paymentQueue.finishTransaction(transaction)
                }
            }
            else {
                unhandledTransactions.append(transaction)
            }
        }
        completeTransactions.callback(products)

        return unhandledTransactions
    }
}
