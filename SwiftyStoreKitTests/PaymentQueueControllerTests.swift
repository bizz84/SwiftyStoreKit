//
// PaymentQueueControllerTests.swift
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

import XCTest
import SwiftyStoreKit
import StoreKit

extension Payment {
    public init(product: SKProduct, atomically: Bool, applicationUsername: String, callback: @escaping (TransactionResult) -> ()) {
        self.product = product
        self.atomically = atomically
        self.applicationUsername = applicationUsername
        self.callback = callback
    }
}

class PaymentQueueControllerTests: XCTestCase {

    // MARK: init/deinit
    func testInit_registersAsObserver() {
        
        let spy = PaymentQueueSpy()
        
        let paymentQueueController = PaymentQueueController(paymentQueue: spy)
        
        XCTAssertTrue(spy.observer === paymentQueueController)
    }
    
    func testDeinit_removesObserver() {
        
        let spy = PaymentQueueSpy()
        
        let _ = PaymentQueueController(paymentQueue: spy)
        
        XCTAssertNil(spy.observer)
    }
    
    // MARK: Start payment
    
    func testStartTransaction_QueuesOnePayment() {
        
        let spy = PaymentQueueSpy()
        
        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        let payment = makeTestPayment(productIdentifier: "com.SwiftyStoreKit.product1") { result in }

        paymentQueueController.startPayment(payment)
        
        XCTAssertEqual(spy.payments.count, 1)
    }
    
    // MARK: SKPaymentTransactionObserver callbacks
    func testPaymentQueue_when_oneTransactionForEachState_then_correctCallbacksCalled() {

        // setup
        let spy = PaymentQueueSpy()
        
        let paymentQueueController = PaymentQueueController(paymentQueue: spy)

        let purchasedProductIdentifier = "com.SwiftyStoreKit.product1"
        let failedProductIdentifier = "com.SwiftyStoreKit.product2"
        let restoredProductIdentifier = "com.SwiftyStoreKit.product3"
        let deferredProductIdentifier = "com.SwiftyStoreKit.product4"
        let purchasingProductIdentifier = "com.SwiftyStoreKit.product5"
        
        let transactions = [
            makeTestPaymentTransaction(productIdentifier: purchasedProductIdentifier, transactionState: .purchased),
            makeTestPaymentTransaction(productIdentifier: failedProductIdentifier, transactionState: .failed),
            makeTestPaymentTransaction(productIdentifier: restoredProductIdentifier, transactionState: .restored),
            makeTestPaymentTransaction(productIdentifier: deferredProductIdentifier, transactionState: .deferred),
            makeTestPaymentTransaction(productIdentifier: purchasingProductIdentifier, transactionState: .purchasing),
            ]

        
        var paymentCallbackCalled = false
        let testPayment = makeTestPayment(productIdentifier: purchasedProductIdentifier) { result in
            paymentCallbackCalled = true
            if case .purchased(let product) = result {
                XCTAssertEqual(product.productId, purchasedProductIdentifier)
            }
            else {
                XCTFail("expected purchased callback with product id")
            }
        }

        var restorePurchasesCallbackCalled = false
        let restorePurchases = RestorePurchases(atomically: true) { results in
            restorePurchasesCallbackCalled = true
            XCTAssertEqual(results.count, 1)
            let first = results.first!
            if case .restored(let restoredProduct) = first {
                XCTAssertEqual(restoredProduct.productId, restoredProductIdentifier)
            }
            else {
                XCTFail("expected restored callback with product")
            }
        }
        
        var completeTransactionsCallbackCalled = false
        let completeTransactions = CompleteTransactions(atomically: true) { products in
            completeTransactionsCallbackCalled = true
            XCTAssertEqual(products.count, 2)
            XCTAssertEqual(products[0].productId, failedProductIdentifier)
            XCTAssertEqual(products[1].productId, deferredProductIdentifier)
        }
        
        // run
        paymentQueueController.startPayment(testPayment)
        
        paymentQueueController.restorePurchases(restorePurchases)

        paymentQueueController.completeTransactions(completeTransactions)
        
        paymentQueueController.paymentQueue(SKPaymentQueue(), updatedTransactions: transactions)
        paymentQueueController.paymentQueueRestoreCompletedTransactionsFinished(SKPaymentQueue())
        
        // verify
        XCTAssertTrue(paymentCallbackCalled)
        XCTAssertTrue(restorePurchasesCallbackCalled)
        XCTAssertTrue(completeTransactionsCallbackCalled)
    }
    
    
    // MARK: Helpers
    func makeTestPaymentTransaction(productIdentifier: String, transactionState: SKPaymentTransactionState) -> TestPaymentTransaction {
        
        let testProduct = TestProduct(productIdentifier: productIdentifier)
        return TestPaymentTransaction(payment: SKPayment(product: testProduct), transactionState: transactionState)
    }
    
    func makeTestPayment(productIdentifier: String, atomically: Bool = true, callback: @escaping (TransactionResult) -> ()) -> Payment {
        
        let testProduct = TestProduct(productIdentifier: productIdentifier)
        return Payment(product: testProduct, atomically: atomically, applicationUsername: "", callback: callback)
    }
}
