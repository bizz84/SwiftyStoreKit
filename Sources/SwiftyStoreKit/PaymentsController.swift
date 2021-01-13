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

struct Payment: Hashable {
    let product: SKProduct
    
    let paymentDiscount: PaymentDiscount?
    let quantity: Int
    let atomically: Bool
    let applicationUsername: String
    let simulatesAskToBuyInSandbox: Bool
    let callback: (TransactionResult) -> Void

    func hash(into hasher: inout Hasher) {
        hasher.combine(product)
        hasher.combine(quantity)
        hasher.combine(atomically)
        hasher.combine(applicationUsername)
        hasher.combine(simulatesAskToBuyInSandbox)
    }
    
    static func == (lhs: Payment, rhs: Payment) -> Bool {
        return lhs.product.productIdentifier == rhs.product.productIdentifier
    }
}

public struct PaymentDiscount {
    let discount: AnyObject?
    
    @available(iOS 12.2, tvOS 12.2, OSX 10.14.4, watchOS 6.2, macCatalyst 13.0, *)
    public init(discount: SKPaymentDiscount) {
        self.discount = discount
    }
    
    private init() {
        self.discount = nil
    }
}

class PaymentsController: TransactionController {

    private var payments: [Payment] = []
    private var failedPayments: [Payment] = []

    func hasPayment(_ payment: Payment) -> Bool {
        return payments.firstIndex(withProductIdentifier: payment.product.productIdentifier) != nil
    }

    func append(_ payment: Payment) {
        payments.append(payment)
    }

    func processTransaction(_ transaction: SKPaymentTransaction, on paymentQueue: PaymentQueue) -> Bool {

        let transactionProductIdentifier = transaction.payment.productIdentifier
        let transactionState = transaction.transactionState

        guard let handler = getPaymentHandler(for: transaction) else {
            return false
        }

        let payment = handler.payment

        if transactionState == .purchased {
            let purchase = PurchaseDetails(productId: transactionProductIdentifier, quantity: transaction.payment.quantity, product: payment.product, transaction: transaction, originalTransaction: transaction.original, needsFinishTransaction: !payment.atomically)
            
            payment.callback(.purchased(purchase: purchase))

            if payment.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            handler.cleanup()
            return true
        }

        if transactionState == .restored {
            print("Unexpected restored transaction for payment \(transactionProductIdentifier)")

            let purchase = PurchaseDetails(productId: transactionProductIdentifier, quantity: transaction.payment.quantity, product: payment.product, transaction: transaction, originalTransaction: transaction.original, needsFinishTransaction: !payment.atomically)

            payment.callback(.purchased(purchase: purchase))

            if payment.atomically {
                paymentQueue.finishTransaction(transaction)
            }
            handler.cleanup()
            return true
        }

        if transactionState == .failed {

            payment.callback(.failed(error: transactionError(for: transaction.error as NSError?)))

            paymentQueue.finishTransaction(transaction)
            handler.cleanup()
            failedPayments.append(payment)
            return true
        }

        return false
    }

    func transactionError(for error: NSError?) -> SKError {
        let message = "Unknown error"
        let altError = NSError(domain: SKErrorDomain, code: SKError.unknown.rawValue, userInfo: [ NSLocalizedDescriptionKey: message ])
        let nsError = error ?? altError
        return SKError(_nsError: nsError)
    }

    func processTransactions(_ transactions: [SKPaymentTransaction], on paymentQueue: PaymentQueue) -> [SKPaymentTransaction] {

        return transactions.filter { !processTransaction($0, on: paymentQueue) }
    }

    private struct PaymentHandler {
        var payment: Payment
        var cleanup: () -> Void
    }

    private func getPaymentHandler(for transaction: SKPaymentTransaction) -> PaymentHandler? {
        let transactionProductIdentifier = transaction.payment.productIdentifier
        let transactionState = transaction.transactionState

        if let paymentIndex = payments.firstIndex(withProductIdentifier: transactionProductIdentifier) {
            return PaymentHandler(
                payment: payments[paymentIndex],
                cleanup: {
                    self.payments.remove(at: paymentIndex)
                }
            )
        }

        // Interrupted purchases will send notifications with state == .purchased after a notification where
        // it's already sent one with failed, so we need to keep track of failed transactions
        // See https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox
        if transactionState == .purchased,
           let failedPaymentIndex = failedPayments.firstIndex(withProductIdentifier: transactionProductIdentifier),
           case let payment = failedPayments[failedPaymentIndex],
           payment.quantity == transaction.payment.quantity {
            return PaymentHandler(
                payment: payment,
                cleanup: {
                    self.failedPayments.remove(at: failedPaymentIndex)
                }
            )
        }

        return nil
    }
}

private extension Array where Element == Payment {
    func firstIndex(withProductIdentifier identifier: String) -> Int? {
        return firstIndex { $0.product.productIdentifier == identifier }
    }
}
