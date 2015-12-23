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

// Info for receipt return by server
public typealias ReceiptInfo = [String: AnyObject]

// MARK: - Enumeration

public enum ValidReceiptResultType {
    case Success(receipt: ReceiptInfo)
    case Error(error: ReceiptError)
}

public enum ReceiptError : ErrorType {
    case NoReceiptData
    case NoRemoteData
    case RequestBodyEncodeError(error: ErrorType)
    case JSONDecodeError(string: String?)
    case NetworkError(error: ErrorType)
    case AppStore(status: Int)
    case ReceiptInvalid(receipt: ReceiptInfo, status: ReceiptStatus)
}

// Status code returned by remote server
// see Table 2-1  Status codes
public enum ReceiptStatus: Int {
    case Unknown = -2 // Not decodable status
    case None = -1 // No status returned

    case Valid = 0 // valid status

    case JSONNotReadable = 21000 // The App Store could not read the JSON object you provided.
    case MalformedOrMissingData = 21002 // The data in the receipt-data property was malformed or missing.

    case ReceiptCouldNotBeAuthenticated = 21003 // The receipt could not be authenticated.
    case SecretNotMatching = 21004 // The shared secret you provided does not match the shared secret on file for your account.
    case ReceiptServerUnavailable = 21005 // The receipt server is not currently available.
    case SubscriptionExpired = 21006 // This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.
    case TestReceipt = 21007 //  This receipt is from the test environment, but it was sent to the production environment for verification. Send it to the test environment instead.
    case ProductionEnvironment = 21008 // This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead.
}

// Receipt field as defined in : https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1
public enum ReceiptInfoField {
    case bundle_id // Bundle Identifier. This corresponds to the value of CFBundleIdentifier in the Info.plist file.
    case application_version //  The app’s version number.This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist.
    case  original_application_version // The version of the app that was originally purchased. This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made.
    case creation_date // The date when the app receipt was created.
    case expiration_date // The date that the app receipt expires. This key is present only for apps purchased through the Volume Purchase Program.

    case in_app // The receipt for an in-app purchase.

    public enum InApp {

        case quantity// The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.

        case product_id // The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.

        case transaction_id // The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.

        case original_transaction_id// For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s transactionIdentifier property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.

        case purchase_date // The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.

        case original_purchase_date // For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s transactionDate property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.

        case expires_date// The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is only present for auto-renewable subscription receipts.

        case cancellation_date // For a transaction that was canceled by Apple customer support, the time and date of the cancellation. Treat a canceled receipt the same as if no purchase had ever been made.

        #if os(iOS)
        case app_item_id // A string that the App Store uses to uniquely identify the application that created the transaction. If your server supports multiple applications, you can use this value to differentiate between them. Apps are assigned an identifier only in the production environment, so this key is not present for receipts created in the test environment. This field is not present for Mac apps. See also Bundle Identifier.
        #endif

        case version_external_identifier // An arbitrary number that uniquely identifies a revision of your application. This key is not present for receipts created in the test environment.
        
        case web_order_line_item_id // The primary key for identifying subscription purchases.
    }
}

// URL used to verify
public enum ReceiptVerifyURL: String {
    case Production = "https://buy.itunes.apple.com/verifyReceipt"
    case Test = "https://sandbox.itunes.apple.com/verifyReceipt"
}
extension Bool {
    var toReceiptVerifyURL: ReceiptVerifyURL {
        return self ? .Test : .Production
    }
}

#if os(OSX)
    public enum ReceiptExitCode: Int32 {
        case NotValid = 173 // If validation fails in OS X, call exit with a status of 173. This exit status notifies the system that your application has determined that its receipt is invalid. At this point, the system attempts to obtain a valid receipt and may prompt for the user’s iTunes credentials
    }
#endif

// MARK - receipt mangement
internal class InAppReceipt {

    static var URL: NSURL? {
        return NSBundle.mainBundle().appStoreReceiptURL
    }

    static var data: NSData? {
        if let receiptDataURL = URL, data = NSData(contentsOfURL: receiptDataURL) {
            return data
        }
        print(NSBundle.mainBundle().appStoreReceiptURL)
        return nil
    }

    // The base64 encoded receipt data.
    static var base64EncodedString: String? {
        return data?.base64EncodedStringWithOptions([])
    }

    // https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html

   /**
    *  - Parameter test: if true use test environment remote URL otherwise production one (default: true)
    *  - Parameter password: Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).
    *  - Parameter session: the session used to make remote call.
    *  - Parameter completion: handler for result
    */
    class func verify(
        test: Bool = true,
        password autoRenewPassword: String? = nil,
        session: NSURLSession = NSURLSession.sharedSession(),
        completion:(result: ValidReceiptResultType) -> ()) {

            // If no receipt is present, validation fails.
            guard let base64EncodedString = self.base64EncodedString else {
                completion(result: .Error(error: .NoReceiptData))
                return
            }

            // Create request
            let storeURL = NSURL(string: test.toReceiptVerifyURL.rawValue)! // safe (until no more)
            let storeRequest = NSMutableURLRequest(URL: storeURL)
            storeRequest.HTTPMethod = "POST"


            let requestContents :NSMutableDictionary = [ "receipt-data" : base64EncodedString]
            // password if defined
            if let password = autoRenewPassword {
                requestContents.setValue(password, forKey: "password")
            }

            // Encore request body
            do {
                storeRequest.HTTPBody = try NSJSONSerialization.dataWithJSONObject(requestContents, options: [])
            } catch let e {
                completion(result: .Error(error: .RequestBodyEncodeError(error: e)))
                return
            }

            // Remote task
            let task = session.dataTaskWithRequest(storeRequest) { data, response, error -> Void in

                // there is an error
                if let networkError = error {
                    completion(result: .Error(error: .NetworkError(error: networkError)))
                    return
                }

                // there is no data
                guard let safeData = data else {
                    completion(result:.Error(error: .NoRemoteData))
                    return
                }

                // cannot decode data
                guard let receiptInfo = try? NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves) as? ReceiptInfo ?? [:] else {
                    let jsonStr = String(data: safeData, encoding: NSUTF8StringEncoding)
                    completion(result: .Error(error: .JSONDecodeError(string: jsonStr)))
                    return
                }

                // get status from info
                if let status = receiptInfo["status"] as? Int {
                    if status == ReceiptStatus.Valid.rawValue {
                        completion(result: .Success(receipt: receiptInfo))
                    }
                    else {
                        completion(result: .Error(error: .ReceiptInvalid(receipt: receiptInfo, status: ReceiptStatus(rawValue: status) ?? ReceiptStatus.Unknown)))
                    }
                }
                else {
                    completion(result: .Error(error: .ReceiptInvalid(receipt: receiptInfo, status: ReceiptStatus.None)))
                }
            }
            task.resume()
    }
    
}
