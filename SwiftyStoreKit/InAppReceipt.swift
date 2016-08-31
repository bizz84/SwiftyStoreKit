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

// Info for receipt returned by server
public typealias ReceiptInfo = [String: AnyObject]

// MARK: - Enumeration
extension SwiftyStoreKit {
    public enum VerifyReceiptResult {
        case success(receipt: ReceiptInfo)
        case error(error: ReceiptError)
    }
  
    // Result for Consumable and NonConsumable
    public enum VerifyPurchaseResult {
        case purchased
        case notPurchased
    }
  
    //  Result for Subscription
    public enum VerifySubscriptionResult {
        case purchased(expiryDate: Date)
        case expired(expiryDate: Date)
        case notPurchased
    }
}

// Error when managing receipt
public enum ReceiptError: Swift.Error {
    // No receipt data
    case noReceiptData
    // No data receice
    case noRemoteData
    // Error when encoding HTTP body into JSON
    case requestBodyEncodeError(error: Swift.Error)
    // Error when proceeding request
    case networkError(error: Swift.Error)
    // Error when decoding response
    case jsonDecodeError(string: String?)
    // Receive invalid - bad status returned
    case receiptInvalid(receipt: ReceiptInfo, status: ReceiptStatus)
}

// Status code returned by remote server
// see Table 2-1  Status codes
public enum ReceiptStatus: Int {
    // Not decodable status
    case unknown = -2
    // No status returned
    case none = -1
    // valid statu
    case valid = 0
    // The App Store could not read the JSON object you provided.
    case jsonNotReadable = 21000
    // The data in the receipt-data property was malformed or missing.
    case malformedOrMissingData = 21002
    // The receipt could not be authenticated.
    case receiptCouldNotBeAuthenticated = 21003
    // The shared secret you provided does not match the shared secret on file for your account.
    case secretNotMatching = 21004
    // The receipt server is not currently available.
    case receiptServerUnavailable = 21005
    // This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.
    case subscriptionExpired = 21006
    //  This receipt is from the test environment, but it was sent to the production environment for verification. Send it to the test environment instead.
    case testReceipt = 21007
    // This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead.
    case productionEnvironment = 21008

    var isValid: Bool { return self == .valid}
}

// Receipt field as defined in : https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1
public enum ReceiptInfoField: String {
     // Bundle Identifier. This corresponds to the value of CFBundleIdentifier in the Info.plist file.
    case bundle_id
    // The app’s version number.This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist.
    case application_version
    // The version of the app that was originally purchased. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made.
    case original_application_version
    // The date when the app receipt was created.
    case creation_date
    // The date that the app receipt expires. This key is present only for apps purchased through the Volume Purchase Program.
    case expiration_date

    // The receipt for an in-app purchase.
    case in_app

    public enum InApp: String {
        // The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
        case quantity
        // The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
        case product_id
        // The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
        case transaction_id
        // For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s transactionIdentifier property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
        case original_transaction_id
        // The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
        case purchase_date
        // For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s transactionDate property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
        case original_purchase_date
        // The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is only present for auto-renewable subscription receipts.
        case expires_date
        // For a transaction that was canceled by Apple customer support, the time and date of the cancellation. Treat a canceled receipt the same as if no purchase had ever been made.
        case cancellation_date
        #if os(iOS) || os(tvOS)
        // A string that the App Store uses to uniquely identify the application that created the transaction. If your server supports multiple applications, you can use this value to differentiate between them. Apps are assigned an identifier only in the production environment, so this key is not present for receipts created in the test environment. This field is not present for Mac apps. See also Bundle Identifier.
        case app_item_id
        #endif
        // An arbitrary number that uniquely identifies a revision of your application. This key is not present for receipts created in the test environment.
        case version_external_identifier
        // The primary key for identifying subscription purchases.
        case web_order_line_item_id
    }
}

#if os(OSX)
    public enum ReceiptExitCode: Int32 {
        // If validation fails in OS X, call exit with a status of 173. This exit status notifies the system that your application has determined that its receipt is invalid. At this point, the system attempts to obtain a valid receipt and may prompt for the user’s iTunes credentials
        case notValid = 173
    }
#endif

// MARK - receipt mangement
internal class InAppReceipt {

    // URL used to verify remotely receipt
    enum ReceiptVerifyURL: String {
        case Production = "https://buy.itunes.apple.com/verifyReceipt"
        case Test = "https://sandbox.itunes.apple.com/verifyReceipt"
    }

    static var URL: Foundation.URL? {
        return Bundle.main.appStoreReceiptURL
    }

    static var data: Data? {
        if let receiptDataURL = URL, let data = try? Data(contentsOf: receiptDataURL) {
            return data
        }
        return nil
    }

    // The base64 encoded receipt data.
    static var base64EncodedString: String? {
        return data?.base64EncodedString(options: [])
    }

    // https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html

   /**
    *  - Parameter receiptVerifyURL: receipt verify url (default: Production)
    *  - Parameter password: Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).
    *  - Parameter session: the session used to make remote call.
    *  - Parameter completion: handler for result
    */
    class func verify(
        receiptVerifyURL url: ReceiptVerifyURL = .Production,
        password autoRenewPassword: String? = nil,
        session: URLSession = URLSession.shared,
        completion: @escaping (_ result: SwiftyStoreKit.VerifyReceiptResult) -> ()) {

            // If no receipt is present, validation fails.
            guard let base64EncodedString = self.base64EncodedString else {
                completion(.error(error: .noReceiptData))
                return
            }

            // Create request
            let storeURL = Foundation.URL(string: url.rawValue)! // safe (until no more)
            let storeRequest = NSMutableURLRequest(url: storeURL)
            storeRequest.httpMethod = "POST"


            let requestContents :NSMutableDictionary = [ "receipt-data" : base64EncodedString]
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
                        verify(receiptVerifyURL: .Test, password: autoRenewPassword, session: session, completion: completion)
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
    ) -> SwiftyStoreKit.VerifyPurchaseResult {
      
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
    ) -> SwiftyStoreKit.VerifySubscriptionResult {
      
        // Verify that at least one receipt has the right product id
        let receiptsInfo = getReceiptsInfo(forProductId: productId, inReceipt: receipt)
        if receiptsInfo.count == 0 {
            return .notPurchased
        }
    
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
        if firstExpiryDate.compare(date) == .orderedDescending {
            
            // The subscription is valid
            return .purchased(expiryDate: firstExpiryDate)
        }
        else {
            // The subscription is expired
            return .expired(expiryDate: firstExpiryDate)
        }
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
