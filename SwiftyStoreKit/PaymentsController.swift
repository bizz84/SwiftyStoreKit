//
// PaymentsController.swift
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

public struct Payment: Hashable {
    public let product: SKProduct
    public let atomically: Bool
    public let applicationUsername: String
    public let callback: (TransactionResult) -> ()
    
    public var hashValue: Int {
        return product.productIdentifier.hashValue
    }
    public static func ==(lhs: Payment, rhs: Payment) -> Bool {
        return lhs.product.productIdentifier == rhs.product.productIdentifier
    }
}

public class PaymentsController: TransactionController {
    
    private var payments: [Payment] = []
    
    public init() { }
    
    private func findPaymentIndex(withProductIdentifier identifier: String) -> Int? {
        for payment in payments {
            if payment.product.productIdentifier == identifier {
                return payments.index(of: payment)
            }
        }
        return nil
    }
    
    public func hasPayment(_ payment: Payment) -> Bool {
        return findPaymentIndex(withProductIdentifier: payment.product.productIdentifier) != nil
    }
    
    public func append(_ payment: Payment) {
        payments.append(payment)
    }
    
    public func processTransaction(_ transaction: SKPaymentTransaction, on paymentQueue: PaymentQueue) -> Bool {
        
        let transactionProductIdentifier = transaction.payment.productIdentifier
        
        guard let paymentIndex = findPaymentIndex(withProductIdentifier: transactionProductIdentifier) else {

            return false
        }
        let payment = payments[paymentIndex]
        
        let transactionState = transaction.transactionState
        
        if transactionState == .purchased {

            let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !payment.atomically)
            
            payment.callback(.purchased(product: product))
            
            if payment.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            payments.remove(at: paymentIndex)
            return true
        }
        if transactionState == .failed {

            let message = "Transaction failed for product ID: \(transactionProductIdentifier)"
            let altError = NSError(domain: SKErrorDomain, code: 0, userInfo: [ NSLocalizedDescriptionKey: message ])
            payment.callback(.failed(error: transaction.error ?? altError))
            
            paymentQueue.finishTransaction(transaction)
            payments.remove(at: paymentIndex)
            return true
        }
        
        if transactionState == .restored {
            print("Unexpected restored transaction for payment \(transactionProductIdentifier)")
        }
        return false
    }
    
    public func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {
        
        return transactions.filter { !processTransaction($0, on: paymentQueue) }
    }
}

