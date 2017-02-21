//
//  InAppReceipt.swift
//  SwiftyStoreKit
//
//  Created by phimage on 22/12/15.
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
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

// MARK - receipt mangement
internal class InAppReceipt {

    static var appStoreReceiptUrl: URL? {
        return Bundle.main.appStoreReceiptURL
    }

    static var appStoreReceiptData: Data? {
        guard let receiptDataURL = appStoreReceiptUrl, let data = try? Data(contentsOf: receiptDataURL) else {
            return nil
        }
        return data
    }

    // The base64 encoded receipt data.
    static var appStoreReceiptBase64Encoded: String? {
        return appStoreReceiptData?.base64EncodedString(options: [])
    }

    // https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html

    /**
     *  - Parameter receiptVerifyURL: receipt verify url (default: Production)
     *  - Parameter password: Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).
     *  - Parameter session: the session used to make remote call.
     *  - Parameter completion: handler for result
     */
    class func verify(
		using validator: ReceiptValidator,
        password autoRenewPassword: String? = nil,
        completion: @escaping (VerifyReceiptResult) -> Void) {

            // If no receipt is present, validation fails.
            guard let base64EncodedString = appStoreReceiptBase64Encoded else {
                completion(.error(error: .noReceiptData))
                return
            }

			validator.validate(receipt: base64EncodedString, password: autoRenewPassword, completion: completion)
    }

    /**
     *  Verify the purchase of a Consumable or NonConsumable product in a receipt
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the purchase
     *  - return: either notPurchased or purchased
     */
    class func verifyPurchase(
        productId: String,
        inReceipt receipt: ReceiptInfo
    ) -> VerifyPurchaseResult {

        // Get receipts info for the product
        let receipts = receipt["receipt"]?["in_app"] as? [ReceiptInfo]
        let receiptsInfo = filterReceiptsInfo(receipts: receipts, withProductId: productId)

        // Verify that at least one receipt has the right product id
        return receiptsInfo.count >= 1 ? .purchased : .notPurchased
    }

    /**
     *  Verify the purchase of a subscription (auto-renewable, free or non-renewing) in a receipt. This method extracts all transactions mathing the given productId and sorts them by date in descending order, then compares the first transaction expiry date against the validUntil value.
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the subscription
     *  - Parameter validUntil: date to check against the expiry date of the subscription. If nil, no verification
     *  - Parameter validDuration: the duration of the subscription. Only required for non-renewable subscription.
     *  - return: either NotPurchased or Purchased / Expired with the expiry date found in the receipt
     */
    class func verifySubscription(
        productId: String,
        inReceipt receipt: ReceiptInfo,
        validUntil date: Date = Date(),
        validDuration duration: TimeInterval? = nil
    ) -> VerifySubscriptionResult {

        // Verify that at least one receipt has the right product id

        // The values of the latest_receipt and latest_receipt_info keys are useful when checking whether an auto-renewable subscription is currently active. By providing any transaction receipt for the subscription and checking these values, you can get information about the currently-active subscription period. If the receipt being validated is for the latest renewal, the value for latest_receipt is the same as receipt-data (in the request) and the value for latest_receipt_info is the same as receipt.
        let receipts = receipt["latest_receipt_info"] as? [ReceiptInfo]
        let receiptsInfo = filterReceiptsInfo(receipts: receipts, withProductId: productId)
        if receiptsInfo.count == 0 {
            return .notPurchased
        }

        let receiptDate = getReceiptRequestDate(inReceipt: receipt) ?? date

        // Return the expires dates sorted desc
        let expiryDateValues = receiptsInfo
            .flatMap { (receipt) -> String? in
                let key: String = duration != nil ? "original_purchase_date_ms" : "expires_date_ms"
                return receipt[key] as? String
            }
            .flatMap { (dateString) -> Date? in
                guard let doubleValue = Double(dateString) else { return nil }
                // If duration is set, create an "expires date" value calculated from the original purchase date
                let addedDuration = duration ?? 0
                let expiryDateDouble = (doubleValue / 1000 + addedDuration)
                return Date(timeIntervalSince1970: expiryDateDouble)
            }
            .sorted { (a, b) -> Bool in
                // Sort by descending date order
                return a.compare(b) == .orderedDescending
            }

        guard let firstExpiryDate = expiryDateValues.first else {
            return .notPurchased
        }

        // Check if at least 1 receipt is valid
        if firstExpiryDate.compare(receiptDate) == .orderedDescending {

            // The subscription is valid
            return .purchased(expiryDate: firstExpiryDate)
        } else {
            // The subscription is expired
            return .expired(expiryDate: firstExpiryDate)
        }
    }

    private class func getReceiptRequestDate(inReceipt receipt: ReceiptInfo) -> Date? {

        guard let receiptInfo = receipt["receipt"] as? ReceiptInfo,
            let requestDateString = receiptInfo["request_date_ms"] as? String,
            let requestDateMs = Double(requestDateString) else {
            return nil
        }
        return Date(timeIntervalSince1970: requestDateMs / 1000)
    }

    /**
     *  Get all the receipts info for a specific product
     *  - Parameter receipts: the receipts array to grab info from
     *  - Parameter productId: the product id
     */
    private class func filterReceiptsInfo(receipts: [ReceiptInfo]?, withProductId productId: String) -> [ReceiptInfo] {

        guard let receipts = receipts else {
            return []
        }

        // Filter receipts with matching product id
        let receiptsMatchingProductId = receipts
            .filter { (receipt) -> Bool in
                let product_id = receipt["product_id"] as? String
                return product_id == productId
            }

        return receiptsMatchingProductId
    }
}
