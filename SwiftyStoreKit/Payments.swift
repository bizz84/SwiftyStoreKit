//
//  Payments.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 17/01/2017.
//  Copyright © 2017 musevisions. All rights reserved.
//

import Foundation
import StoreKit

public enum TransactionResult {
    case purchased(product: Product)
    case restored(product: Product)
    case failed(error: Error)
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

public class PaymentsController {
    
    private var payments: Set<Payment> = []
    
    private func findPayment(withProductIdentifier identifier: String) -> Payment? {
        for payment in payments {
            if payment.product.productIdentifier == identifier {
                return payment
            }
        }
        return nil
    }
    
    public func insert(_ payment: Payment) {
        payments.insert(payment)
    }
    
    public func processTransaction(_ transaction: SKPaymentTransaction, paymentQueue: PaymentQueue) -> Bool {
        
        let transactionProductIdentifier = transaction.payment.productIdentifier
        
        if let payment = findPayment(withProductIdentifier: transactionProductIdentifier) {
            
            let product = Product(productId: transactionProductIdentifier, transaction: transaction, needsFinishTransaction: !payment.atomically)
            
            payment.callback(.purchased(product: product))
            
            if payment.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            payments.remove(payment)
            return true
        }
        return false
    }
}
