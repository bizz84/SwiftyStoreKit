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

public struct ReceiptItem {
    // The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
    public let productId: String
    // The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
    public let quantity: Int
    // The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
    public let transactionId: String
    // For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s transactionIdentifier property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
    public let originalTransactionId: String
    // The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
    public let purchaseDate: Date
    // For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s transactionDate property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
    public let originalPurchaseDate: Date
    // The primary key for identifying subscription purchases.
    public let webOrderLineItemId: String
    // The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is only present for auto-renewable subscription receipts.
    public let subscriptionExpirationDate: Date?
    // For a transaction that was canceled by Apple customer support, the time and date of the cancellation. Treat a canceled receipt the same as if no purchase had ever been made.
    public let cancellationDate: Date?
    
    public let isTrialPeriod: Bool?
    
    public init?(receiptInfo: ReceiptInfo) {
        guard
            let productId = receiptInfo["product_id"] as? String,
            let quantity = receiptInfo["quantity"] as? Int,
            let transactionId = receiptInfo["transaction_id"] as? String,
            let originalTransactionId = receiptInfo["original_transaction_id"] as? String,
            let purchaseDate = ReceiptItem.parseDate(from: receiptInfo, key: "purchase_date_ms"),
            let originalPurchaseDate = ReceiptItem.parseDate(from: receiptInfo, key: "original_purchase_date_ms"),
            let webOrderLineItemId = receiptInfo["web_order_line_item_id"] as? String
            else {
                return nil
        }
        self.productId = productId
        self.quantity = quantity
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.webOrderLineItemId = webOrderLineItemId
        self.subscriptionExpirationDate = ReceiptItem.parseDate(from: receiptInfo, key: "expires_date_ms")
        self.cancellationDate = ReceiptItem.parseDate(from: receiptInfo, key: "cancellation_date_ms")
        self.isTrialPeriod = receiptInfo["is_trial_period"] as? Bool
    }
    
    private static func parseDate(from receiptInfo: ReceiptInfo, key: String) -> Date? {
        
        guard
            let requestDateString = receiptInfo[key] as? String,
            let requestDateMs = Double(requestDateString) else {
                return nil
        }
        return Date(timeIntervalSince1970: requestDateMs / 1000)
    }
}

extension ReceiptItem {

    init(productId: String, purchaseDate: Date, subscriptionExpirationDate: Date? = nil, cancellationDate: Date? = nil, isTrialPeriod: Bool? = nil) {
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
            "original_purchase_date_ms": originalPurchaseDate.timeIntervalSince1970.millisecondsNSString
        ]
        if let subscriptionExpirationDate = subscriptionExpirationDate {
            result["expires_date_ms"] = subscriptionExpirationDate.timeIntervalSince1970.millisecondsNSString
        }
        if let cancellationDate = cancellationDate {
            result["cancellation_date_ms"] = cancellationDate.timeIntervalSince1970.millisecondsNSString
            result["cancellation_date"] = cancellationDate as NSDate
        }
        if let isTrialPeriod = isTrialPeriod {
            result["is_trial_period"] = NSNumber(value: isTrialPeriod)
        }
        return NSDictionary(dictionary: result)
    }
}

extension VerifySubscriptionResult: Equatable {

    public static func == (lhs: VerifySubscriptionResult, rhs: VerifySubscriptionResult) -> Bool {
        switch (lhs, rhs) {
        case (.notPurchased, .notPurchased): return true
        case (.purchased(let lhsExpiryDate), .purchased(let rhsExpiryDate)): return lhsExpiryDate == rhsExpiryDate
        case (.expired(let lhsExpiryDate), .expired(let rhsExpiryDate)): return lhsExpiryDate == rhsExpiryDate
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
        
        XCTAssertEqual(verifyPurchaseResult, .purchased)
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
        
        let expectedSubscriptionResult = VerifySubscriptionResult.expired(expiryDate: expirationDate)
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

        let expectedSubscriptionResult = VerifySubscriptionResult.purchased(expiryDate: expirationDate)
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
        
        let expectedSubscriptionResult = VerifySubscriptionResult.expired(expiryDate: expirationDate)
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
        
        let expectedSubscriptionResult = VerifySubscriptionResult.purchased(expiryDate: expirationDate)
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
    func verifyAutoRenewableSubscription_when_twoSubscriptions_sameProductId_mostRecentNonExpired_then_resultIsPurchased() {
        
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
        
        let expectedSubscriptionResult = VerifySubscriptionResult.purchased(expiryDate: newerExpirationDate)
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
