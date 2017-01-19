//
//  Payments.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 17/01/2017.
//  Copyright © 2017 musevisions. All rights reserved.
//

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

public struct RestorePurchases {
    public let atomically: Bool
    public let callback: ([TransactionResult]) -> ()
    
    public init(atomically: Bool, callback: @escaping ([TransactionResult]) -> ()) {
        self.atomically = atomically
        self.callback = callback
    }
}

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
    
    private var payments: Set<Payment> = []
    
    public init() { }
    
    private func findPayment(withProductIdentifier identifier: String) -> Payment? {
        for payment in payments {
            if payment.product.productIdentifier == identifier {
                return payment
            }
        }
        return nil
    }
    
    public func hasPayment(_ payment: Payment) -> Bool {
        return findPayment(withProductIdentifier: payment.product.productIdentifier) != nil
    }
    
    public func insert(_ payment: Payment) {
        payments.insert(payment)
    }
    
    public func processTransaction(_ transaction: SKPaymentTransaction, on paymentQueue: PaymentQueue) -> Bool {
        
        let transactionProductIdentifier = transaction.payment.productIdentifier
        
        guard let payment = findPayment(withProductIdentifier: transactionProductIdentifier) else {

            return false
        }
        let transactionState = transaction.transactionState
        
        if transactionState == .purchased {

            let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !payment.atomically)
            
            payment.callback(.purchased(product: product))
            
            if payment.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            payments.remove(payment)
            return true
        }
        if transactionState == .failed {

            let message = "Transaction failed for product ID: \(transactionProductIdentifier)"
            let altError = NSError(domain: SKErrorDomain, code: 0, userInfo: [ NSLocalizedDescriptionKey: message ])
            payment.callback(.failed(error: transaction.error ?? altError))
            
            paymentQueue.finishTransaction(transaction)
            payments.remove(payment)
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

public class RestorePurchasesController: TransactionController {

    public var restorePurchases: RestorePurchases?
    
    public init() { }
    
    public func processTransaction(_ transaction: SKPaymentTransaction, atomically: Bool, on paymentQueue: PaymentQueue) -> Product? {
        
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
    
    public func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {
        
        guard let restorePurchases = restorePurchases else {
            return transactions
        }
        
        var unhandledTransactions: [SKPaymentTransaction] = []
        var restoredProducts: [TransactionResult] = []
        for transaction in transactions {
            if let restoredProduct = processTransaction(transaction, atomically: restorePurchases.atomically, on: paymentQueue) {
                restoredProducts.append(.restored(product: restoredProduct))
            }
            else {
                unhandledTransactions.append(transaction)
            }
        }
        if restoredProducts.count > 0 {
            restorePurchases.callback(restoredProducts)
        }
        return unhandledTransactions
    }
    
    public func restoreCompletedTransactionsFailed(withError error: Error) {

        guard let restorePurchases = restorePurchases else {
            return
        }
        restorePurchases.callback([.failed(error: error)])
    }
}
