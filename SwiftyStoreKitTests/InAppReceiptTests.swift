//
//  InAppReceiptTests.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 08/05/2017.
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

private extension TimeInterval {
    var millisecondsNSString: NSString {
        return String(format: "%.0f", self * 1000) as NSString
    }
}

extension ReceiptItem: Equatable {

    init(productId: String, purchaseDate: Date, subscriptionExpirationDate: Date? = nil, cancellationDate: Date? = nil, isTrialPeriod: Bool = false) {
        self.productId = productId
        self.quantity = 1
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = purchaseDate
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.cancellationDate = cancellationDate
        self.transactionId = UUID().uuidString
        self.originalTransactionId = UUID().uuidString
        self.webOrderLineItemId = UUID().uuidString
        self.isTrialPeriod = isTrialPeriod
    }

    var receiptInfo: NSDictionary {
        var result: [String: AnyObject] = [
            "product_id": productId as NSString,
            "quantity": String(quantity) as NSString,
            "purchase_date_ms": purchaseDate.timeIntervalSince1970.millisecondsNSString,
            "original_purchase_date_ms": originalPurchaseDate.timeIntervalSince1970.millisecondsNSString,
            "is_trial_period": (isTrialPeriod ? "1" : "0") as NSString,
            "transaction_id": transactionId as NSString,
            "original_transaction_id": originalTransactionId as NSString
        ]
        if let subscriptionExpirationDate = subscriptionExpirationDate {
            result["expires_date_ms"] = subscriptionExpirationDate.timeIntervalSince1970.millisecondsNSString
        }
        if let cancellationDate = cancellationDate {
            result["cancellation_date_ms"] = cancellationDate.timeIntervalSince1970.millisecondsNSString
            result["cancellation_date"] = cancellationDate as NSDate
        }
        return NSDictionary(dictionary: result)
    }
    
    public static func == (lhs: ReceiptItem, rhs: ReceiptItem) -> Bool {
        return
            lhs.productId == rhs.productId &&
            lhs.quantity == rhs.quantity &&
            lhs.purchaseDate == rhs.purchaseDate &&
            lhs.originalPurchaseDate == rhs.originalPurchaseDate &&
            lhs.subscriptionExpirationDate == rhs.subscriptionExpirationDate &&
            lhs.cancellationDate == rhs.cancellationDate &&
            lhs.isTrialPeriod == rhs.isTrialPeriod
    }
}

extension VerifySubscriptionResult: Equatable {

    public static func == (lhs: VerifySubscriptionResult, rhs: VerifySubscriptionResult) -> Bool {
        switch (lhs, rhs) {
        case (.notPurchased, .notPurchased): return true
        case (.purchased(let lhsExpiryDate, let lhsReceiptItem), .purchased(let rhsExpiryDate, let rhsReceiptItem)):
            return lhsExpiryDate == rhsExpiryDate && lhsReceiptItem == rhsReceiptItem
        case (.expired(let lhsExpiryDate, let lhsReceiptItem), .expired(let rhsExpiryDate, let rhsReceiptItem)):
            return lhsExpiryDate == rhsExpiryDate && lhsReceiptItem == rhsReceiptItem
        default: return false
        }
    }
}

extension VerifyPurchaseResult: Equatable {
    
    public static func == (lhs: VerifyPurchaseResult, rhs: VerifyPurchaseResult) -> Bool {
        switch (lhs, rhs) {
        case (.notPurchased, .notPurchased): return true
        case (.purchased(let lhsReceiptItem), .purchased(let rhsReceiptItem)):
            return lhsReceiptItem == rhsReceiptItem
        default: return false
        }
    }
}

class InAppReceiptTests: XCTestCase {

    // MARK: Verify Purchase
    func testVerifyPurchase_when_noPurchases_then_resultIsNotPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let receipt = makeReceipt(items: [], requestDate: receiptRequestDate)

        let verifyPurchaseResult = SwiftyStoreKit.verifyPurchase(productId: productId, inReceipt: receipt)

        XCTAssertEqual(verifyPurchaseResult, .notPurchased)
    }
    func testVerifyPurchase_when_onePurchase_then_resultIsPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let item = ReceiptItem(productId: productId, purchaseDate: receiptRequestDate, subscriptionExpirationDate: nil, cancellationDate: nil, isTrialPeriod: false)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifyPurchaseResult = SwiftyStoreKit.verifyPurchase(productId: productId, inReceipt: receipt)

        XCTAssertEqual(verifyPurchaseResult, .purchased(item: item))
    }
    func testVerifyPurchase_when_oneCancelledPurchase_then_resultIsNotPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let item = ReceiptItem(productId: productId, purchaseDate: receiptRequestDate, subscriptionExpirationDate: nil, cancellationDate: receiptRequestDate, isTrialPeriod: false)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifyPurchaseResult = SwiftyStoreKit.verifyPurchase(productId: productId, inReceipt: receipt)

        XCTAssertEqual(verifyPurchaseResult, .notPurchased)
    }

    // MARK: Verify Subscription, single receipt item tests
    // auto-renewable, not purchased
    func testVerifyAutoRenewableSubscription_when_noSubscriptions_then_resultIsNotPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let receipt = makeReceipt(items: [], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .autoRenewable, productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.notPurchased
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // auto-renewable, expired
    func testVerifyAutoRenewableSubscription_when_oneExpiredSubscription_then_resultIsExpired() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 15)
        let productId = "product1"
        let isTrialPeriod = false
        let purchaseDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let expirationDate = purchaseDate.addingTimeInterval(60 * 60)
        let item = ReceiptItem(productId: productId, purchaseDate: purchaseDate, subscriptionExpirationDate: expirationDate, cancellationDate: nil, isTrialPeriod: isTrialPeriod)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .autoRenewable, productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.expired(expiryDate: expirationDate, items: [item])
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // auto-renewable, purchased
    func testVerifyAutoRenewableSubscription_when_oneNonExpiredSubscription_then_resultIsPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let isTrialPeriod = false
        let purchaseDate = receiptRequestDate
        let expirationDate = purchaseDate.addingTimeInterval(60 * 60)
        let item = ReceiptItem(productId: productId, purchaseDate: purchaseDate, subscriptionExpirationDate: expirationDate, cancellationDate: nil, isTrialPeriod: isTrialPeriod)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .autoRenewable, productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.purchased(expiryDate: expirationDate, items: [item])
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // auto-renewable, cancelled
    func testVerifyAutoRenewableSubscription_when_oneCancelledSubscription_then_resultIsNotPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let isTrialPeriod = false
        let purchaseDate = receiptRequestDate
        let expirationDate = purchaseDate.addingTimeInterval(60 * 60)
        let cancelledDate = purchaseDate.addingTimeInterval(30 * 60)
        let item = ReceiptItem(productId: productId, purchaseDate: purchaseDate, subscriptionExpirationDate: expirationDate, cancellationDate: cancelledDate, isTrialPeriod: isTrialPeriod)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .autoRenewable, productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.notPurchased
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // non-renewing, non purchased
    func testVerifyNonRenewingSubscription_when_noSubscriptions_then_resultIsNotPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let receipt = makeReceipt(items: [], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .nonRenewing(validDuration: 60 * 60), productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.notPurchased
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // non-renewing, expired
    func testVerifyNonRenewingSubscription_when_oneExpiredSubscription_then_resultIsExpired() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 15)
        let productId = "product1"
        let isTrialPeriod = false
        let purchaseDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let duration: TimeInterval = 60 * 60
        let expirationDate = purchaseDate.addingTimeInterval(duration)

        let item = ReceiptItem(productId: productId, purchaseDate: purchaseDate, subscriptionExpirationDate: nil, cancellationDate: nil, isTrialPeriod: isTrialPeriod)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .nonRenewing(validDuration: duration), productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.expired(expiryDate: expirationDate, items: [item])
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // non-renewing, purchased
    func testVerifyNonRenewingSubscription_when_oneNonExpiredSubscription_then_resultIsPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let isTrialPeriod = false
        let purchaseDate = receiptRequestDate
        let duration: TimeInterval = 60 * 60
        let expirationDate = purchaseDate.addingTimeInterval(duration)

        let item = ReceiptItem(productId: productId, purchaseDate: purchaseDate, subscriptionExpirationDate: nil, cancellationDate: nil, isTrialPeriod: isTrialPeriod)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .nonRenewing(validDuration: duration), productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.purchased(expiryDate: expirationDate, items: [item])
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // non-renewing, cancelled
    func testVerifyNonRenewingSubscription_when_oneCancelledSubscription_then_resultIsNotPurchased() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let productId = "product1"
        let isTrialPeriod = false
        let purchaseDate = receiptRequestDate
        let duration: TimeInterval = 60 * 60
        let cancelledDate = purchaseDate.addingTimeInterval(30 * 60)
        let item = ReceiptItem(productId: productId, purchaseDate: purchaseDate, subscriptionExpirationDate: nil, cancellationDate: cancelledDate, isTrialPeriod: isTrialPeriod)
        let receipt = makeReceipt(items: [item], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .nonRenewing(validDuration: duration), productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.notPurchased
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // MARK: Verify Subscription, multiple receipt item tests
    func verifyAutoRenewableSubscription_when_twoSubscriptions_sameProductId_mostRecentNonExpired_then_resultIsPurchased_itemsSorted() {

        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)

        let productId = "product1"
        let isTrialPeriod = false

        let olderPurchaseDate = makeDateAtMidnight(year: 2017, month: 5, day: 12)
        let olderExpirationDate = olderPurchaseDate.addingTimeInterval(60 * 60)
        let olderItem = ReceiptItem(productId: productId,
                               purchaseDate: olderPurchaseDate,
                               subscriptionExpirationDate: olderExpirationDate,
                               cancellationDate: nil,
                               isTrialPeriod: isTrialPeriod)

        let newerPurchaseDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        let newerExpirationDate = olderPurchaseDate.addingTimeInterval(60 * 60)
        let newerItem = ReceiptItem(productId: productId,
                                    purchaseDate: newerPurchaseDate,
                                    subscriptionExpirationDate: newerExpirationDate,
                                    cancellationDate: nil,
                                    isTrialPeriod: isTrialPeriod)

        let receipt = makeReceipt(items: [olderItem, newerItem], requestDate: receiptRequestDate)

        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .autoRenewable, productId: productId, inReceipt: receipt)

        let expectedSubscriptionResult = VerifySubscriptionResult.purchased(expiryDate: newerExpirationDate, items: [newerItem, olderItem])
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    func verifyAutoRenewableSubscription_when_twoSubscriptions_sameProductId_bothExpired_then_resultIsExpired_itemsSorted() {
        
        let receiptRequestDate = makeDateAtMidnight(year: 2017, month: 5, day: 14)
        
        let productId = "product1"
        let isTrialPeriod = false
        
        let olderPurchaseDate = makeDateAtMidnight(year: 2017, month: 5, day: 12)
        let olderExpirationDate = olderPurchaseDate.addingTimeInterval(60 * 60)
        let olderItem = ReceiptItem(productId: productId,
                                    purchaseDate: olderPurchaseDate,
                                    subscriptionExpirationDate: olderExpirationDate,
                                    cancellationDate: nil,
                                    isTrialPeriod: isTrialPeriod)
        
        let newerPurchaseDate = makeDateAtMidnight(year: 2017, month: 5, day: 13)
        let newerExpirationDate = olderPurchaseDate.addingTimeInterval(60 * 60)
        let newerItem = ReceiptItem(productId: productId,
                                    purchaseDate: newerPurchaseDate,
                                    subscriptionExpirationDate: newerExpirationDate,
                                    cancellationDate: nil,
                                    isTrialPeriod: isTrialPeriod)
        
        let receipt = makeReceipt(items: [olderItem, newerItem], requestDate: receiptRequestDate)
        
        let verifySubscriptionResult = SwiftyStoreKit.verifySubscription(type: .autoRenewable, productId: productId, inReceipt: receipt)
        
        let expectedSubscriptionResult = VerifySubscriptionResult.expired(expiryDate: newerExpirationDate, items: [newerItem, olderItem])
        XCTAssertEqual(verifySubscriptionResult, expectedSubscriptionResult)
    }

    // MARK: Helper methods
    func makeReceipt(items: [ReceiptItem], requestDate: Date) -> [String: AnyObject] {

        let receiptInfos = items.map { $0.receiptInfo }

        // Creating this with NSArray results in __NSSingleObjectArrayI which fails the cast to [String: AnyObject]
        let array = NSMutableArray()
        array.addObjects(from: receiptInfos)

        return [
            //"latest_receipt": [:],
            "status": "200" as NSString,
            "environment": "Sandbox" as NSString,
            "receipt": NSDictionary(dictionary: [
                "request_date_ms": requestDate.timeIntervalSince1970.millisecondsNSString,
                "in_app": array // non renewing
            ]),
            "latest_receipt_info": array // autoRenewable
        ]
    }

    func makeDateAtMidnight(year: Int, month: Int, day: Int) -> Date {

        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = year
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: dateComponents)!
    }
}
