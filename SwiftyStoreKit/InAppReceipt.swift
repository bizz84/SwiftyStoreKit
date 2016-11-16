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

    // URL used to verify remotely receipt
    enum VerifyReceiptURLType: String {
        case production = "https://buy.itunes.apple.com/verifyReceipt"
        case sandbox = "https://sandbox.itunes.apple.com/verifyReceipt"
    }

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
        urlType: VerifyReceiptURLType = .production,
        password autoRenewPassword: String? = nil,
        session: URLSession = URLSession.shared,
        completion: @escaping (VerifyReceiptResult) -> ()) {

            // If no receipt is present, validation fails.
            guard let base64EncodedString = appStoreReceiptBase64Encoded else {
                completion(.error(error: .noReceiptData))
                return
            }

            // Create request
            let storeURL = URL(string: urlType.rawValue)! // safe (until no more)
            let storeRequest = NSMutableURLRequest(url: storeURL)
            storeRequest.httpMethod = "POST"


            let requestContents: NSMutableDictionary = [ "receipt-data" : base64EncodedString ]
            // password if defined
            if let password = autoRenewPassword {
                requestContents.setValue(password, forKey: "password")
            }

            // Encore request body
            do {
                storeRequest.httpBody = try JSONSerialization.data(withJSONObject: requestContents, options: [])
            } catch let e {
                completion(.error(error: .requestBodyEncodeError(error: e)))
                return
            }

            // Remote task
            let task = session.dataTask(with: storeRequest as URLRequest) { data, response, error -> Void in

                // there is an error
                if let networkError = error {
                    completion(.error(error: .networkError(error: networkError)))
                    return
                }

                // there is no data
                guard let safeData = data else {
                    completion(.error(error: .noRemoteData))
                    return
                }

                // cannot decode data
                guard let receiptInfo = try? JSONSerialization.jsonObject(with: data!, options: .mutableLeaves) as? ReceiptInfo ?? [:] else {
                    let jsonStr = String(data: safeData, encoding: String.Encoding.utf8)
                    completion(.error(error: .jsonDecodeError(string: jsonStr)))
                    return
                }

                // get status from info
                if let status = receiptInfo["status"] as? Int {
                    /*
                     * http://stackoverflow.com/questions/16187231/how-do-i-know-if-an-in-app-purchase-receipt-comes-from-the-sandbox
                     * How do I verify my receipt (iOS)?
                     * Always verify your receipt first with the production URL; proceed to verify
                     * with the sandbox URL if you receive a 21007 status code. Following this
                     * approach ensures that you do not have to switch between URLs while your
                     * application is being tested or reviewed in the sandbox or is live in the
                     * App Store.

                     * Note: The 21007 status code indicates that this receipt is a sandbox receipt,
                     * but it was sent to the production service for verification.
                     */
                    let receiptStatus = ReceiptStatus(rawValue: status) ?? ReceiptStatus.unknown
                    if case .testReceipt = receiptStatus {
                        verify(urlType: .sandbox, password: autoRenewPassword, session: session, completion: completion)
                    }
                    else {
                        if receiptStatus.isValid {
                            completion(.success(receipt: receiptInfo))
                        }
                        else {
                            completion(.error(error: .receiptInvalid(receipt: receiptInfo, status: receiptStatus)))
                        }
                    }
                }
                else {
                    completion(.error(error: .receiptInvalid(receipt: receiptInfo, status: ReceiptStatus.none)))
                }
            }
            task.resume()
    }
  
    /**
     *  Verify the purchase of a Consumable or NonConsumable product in a receipt
     *  - Parameter productId: the product id of the purchase to verify
     *  - Parameter inReceipt: the receipt to use for looking up the purchase
     *  - return: either NotPurchased or Purchased
     */
    class func verifyPurchase(
        productId: String,
        inReceipt receipt: ReceiptInfo
    ) -> VerifyPurchaseResult {
      
        // Get receipts info for the product
        let receiptsInfo = getReceiptsInfo(forProductId: productId, inReceipt: receipt)
      
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
        let receiptsInfo = getReceiptsInfo(forProductId: productId, inReceipt: receipt)
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
        }
        else {
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
     *  - Parameter productId: the product id
     *  - Parameter inReceipt: the receipt to grab info from
     */
    private class func getReceiptsInfo(
        forProductId productId: String,
        inReceipt receipt: ReceiptInfo
    ) -> [ReceiptInfo] {
        // Get all receipts
        guard let allReceipts = receipt["receipt"]?["in_app"] as? [ReceiptInfo] else {
            return []
        }
      
        // Filter receipts with matching product id
        let receiptsMatchingProductId = allReceipts
            .filter { (receipt) -> Bool in
                let product_id = receipt["product_id"] as? String
                return product_id == productId
            }
      
        return receiptsMatchingProductId
    }
}
