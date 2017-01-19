//
// PaymentsControllerTests.swift
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

class PaymentsControllerTests: XCTestCase {

    func testInsertPayment_hasPayment() {
     
        let payment = makeTestPayment(productIdentifier: "com.SwiftyStoreKit.product1") { result in }

        let paymentsController = makePaymentsController(insertPayment: payment)
        
        XCTAssertTrue(paymentsController.hasPayment(payment))
    }
    
    func testProcessTransaction_when_transactionStatePurchased_then_removesPayment_finishesTransaction_callsCallback() {
        
        let productIdentifier = "com.SwiftyStoreKit.product1"
        let product = TestProduct(productIdentifier: productIdentifier)
        
        var callbackCalled = false
        let payment = makeTestPayment(product: product) { result in
            
            callbackCalled = true
            if case .purchased(let product) = result {
                XCTAssertEqual(product.productId, productIdentifier)
            }
            else {
                XCTFail("expected purchased callback with product id")
            }
        }
        
        let paymentsController = makePaymentsController(insertPayment: payment)
        
        let transaction = TestPaymentTransaction(payment: SKPayment(product: product), transactionState: .purchased)
        
        let spy = PaymentQueueSpy()
        
        let remainingTransactions = paymentsController.processTransactions([transaction], on: spy)
        
        XCTAssertEqual(remainingTransactions.count, 0)

        XCTAssertFalse(paymentsController.hasPayment(payment))
        
        XCTAssertTrue(callbackCalled)
        
        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }
    
    func testProcessTransaction_when_transactionStateFailed_then_removesPayment_finishesTransaction_callsCallback() {
        
        let productIdentifier = "com.SwiftyStoreKit.product1"
        let product = TestProduct(productIdentifier: productIdentifier)
        
        var callbackCalled = false
        let payment = makeTestPayment(product: product) { result in
            
            callbackCalled = true
            if case .failed(_) = result {
                
            }
            else {
                XCTFail("expected failed callback with error")
            }
        }
        
        let paymentsController = makePaymentsController(insertPayment: payment)
        
        let transaction = TestPaymentTransaction(payment: SKPayment(product: product), transactionState: .failed)
        
        let spy = PaymentQueueSpy()
        
        let remainingTransactions = paymentsController.processTransactions([transaction], on: spy)
        
        XCTAssertEqual(remainingTransactions.count, 0)
        
        XCTAssertFalse(paymentsController.hasPayment(payment))
        
        XCTAssertTrue(callbackCalled)
        
        XCTAssertEqual(spy.finishTransactionCalledCount, 1)
    }
    
    func makePaymentsController(insertPayment payment: Payment) -> PaymentsController {
        
        let paymentsController = PaymentsController()
        
        paymentsController.insert(payment)
        
        return paymentsController
    }
    
    func makeTestPayment(product: SKProduct, atomically: Bool = true, callback: @escaping (TransactionResult) -> ()) -> Payment {
        
        return Payment(product: product, atomically: atomically, applicationUsername: "", callback: callback)
    }
    
    func makeTestPayment(productIdentifier: String, atomically: Bool = true, callback: @escaping (TransactionResult) -> ()) -> Payment {

        let product = TestProduct(productIdentifier: productIdentifier)
        return makeTestPayment(product: product, atomically: atomically, callback: callback)

    }
}
