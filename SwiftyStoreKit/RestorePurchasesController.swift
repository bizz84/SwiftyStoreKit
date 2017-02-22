//
// RestorePurchasesController.swift
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

struct RestorePurchases {
    let atomically: Bool
    let applicationUsername: String?
    let callback: ([TransactionResult]) -> ()
    
    init(atomically: Bool, applicationUsername: String? = nil, callback: @escaping ([TransactionResult]) -> ()) {
        self.atomically = atomically
        self.applicationUsername = applicationUsername
        self.callback = callback
    }
}

class RestorePurchasesController: TransactionController {
    
    public var restorePurchases: RestorePurchases?
    
    private var restoredProducts: [TransactionResult] = []
    
    func processTransaction(_ transaction: SKPaymentTransaction, atomically: Bool, on paymentQueue: PaymentQueue) -> Product? {
        
        let transactionState = transaction.transactionState
        
        if transactionState == .restored {
            
            let transactionProductIdentifier = transaction.payment.productIdentifier
            
            let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !atomically)
            if atomically {
                paymentQueue.finishTransaction(transaction)
            }
            return product
        }
        return nil
    }
    
    func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {
        
        guard let restorePurchases = restorePurchases else {
            return transactions
        }
        
        var unhandledTransactions: [SKPaymentTransaction] = []
        for transaction in transactions {
            if let restoredProduct = processTransaction(transaction, atomically: restorePurchases.atomically, on: paymentQueue) {
                restoredProducts.append(.restored(product: restoredProduct))
            }
            else {
                unhandledTransactions.append(transaction)
            }
        }

        return unhandledTransactions
    }
    
    func restoreCompletedTransactionsFailed(withError error: Error) {
        
        guard let restorePurchases = restorePurchases else {
            return
        }
        restoredProducts.append(.failed(error: SKError(_nsError: error as NSError)))
        restorePurchases.callback(restoredProducts)
        
        // Reset state after error received
        restoredProducts = []
        self.restorePurchases = nil

    }
    
    func restoreCompletedTransactionsFinished() {
        
        guard let restorePurchases = restorePurchases else {
            return
        }
        restorePurchases.callback(restoredProducts)
        
        // Reset state after error transactions finished
        restoredProducts = []
        self.restorePurchases = nil
    }
}
