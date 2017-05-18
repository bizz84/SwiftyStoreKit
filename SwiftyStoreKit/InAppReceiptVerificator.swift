//
//  InAppReceiptVerificator.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 16/05/2017.
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

class InAppReceiptVerificator: NSObject {

    let appStoreReceiptURL: URL?
    init(appStoreReceiptURL: URL? = Bundle.main.appStoreReceiptURL) {
        self.appStoreReceiptURL = appStoreReceiptURL
    }

    var appStoreReceiptData: Data? {
        guard let receiptDataURL = appStoreReceiptURL,
            let data = try? Data(contentsOf: receiptDataURL) else {
            return nil
        }
        return data
    }

    private var receiptRefreshRequest: InAppReceiptRefreshRequest?

    /**
     *  Verify application receipt. This method does two things:
     *  * If the receipt is missing, refresh it
     *  * If the receipt is available or is refreshed, validate it
     *  - Parameter validator: Validator to check the encrypted receipt and return the receipt in readable format
     *  - Parameter password: Your app’s shared secret (a hexadecimal string). Only used for receipts that contain auto-renewable subscriptions.
     *  - Parameter refresh: closure to perform receipt refresh (this is made explicit for testability)
     *  - Parameter completion: handler for result
     */
    public func verifyReceipt(using validator: ReceiptValidator,
                              password: String? = nil,
                              refresh: InAppReceiptRefreshRequest.ReceiptRefresh = InAppReceiptRefreshRequest.refresh,
                              completion: @escaping (VerifyReceiptResult) -> Void) {
        
        if let receiptData = appStoreReceiptData {
            
            verify(receiptData: receiptData, using: validator, password: password, completion: completion)
        } else {
            
            receiptRefreshRequest = refresh(nil) { result in
                
                self.receiptRefreshRequest = nil
                
                switch result {
                case .success:
                    if let receiptData = self.appStoreReceiptData {
                        self.verify(receiptData: receiptData, using: validator, password: password, completion: completion)
                    } else {
                        completion(.error(error: .noReceiptData))
                    }
                case .error(let e):
                    completion(.error(error: .networkError(error: e)))
                }
            }
        }
    }
    
    /**
     *  - Parameter receiptData: encrypted receipt data
     *  - Parameter validator: Validator to check the encrypted receipt and return the receipt in readable format
     *  - Parameter password: Your app’s shared secret (a hexadecimal string). Only used for receipts that contain auto-renewable subscriptions.
     *  - Parameter completion: handler for result
     */
    private func verify(receiptData: Data, using validator: ReceiptValidator, password: String? = nil, completion: @escaping (VerifyReceiptResult) -> Void) {
     
        // The base64 encoded receipt data.
        let base64EncodedString = receiptData.base64EncodedString(options: [])

        validator.validate(receipt: base64EncodedString, password: password) { result in
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
