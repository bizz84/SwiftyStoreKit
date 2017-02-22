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

public struct AppleReceiptValidator: ReceiptValidator {

	public enum VerifyReceiptURLType: String {
		case production = "https://buy.itunes.apple.com/verifyReceipt"
		case sandbox = "https://sandbox.itunes.apple.com/verifyReceipt"
	}

	public init(service: VerifyReceiptURLType = .production) {
		self.service = service
	}

	private let service: VerifyReceiptURLType

	public func validate(
		receipt: String,
		password autoRenewPassword: String? = nil,
		completion: @escaping (VerifyReceiptResult) -> Void) {

		let storeURL = URL(string: service.rawValue)! // safe (until no more)
		let storeRequest = NSMutableURLRequest(url: storeURL)
		storeRequest.httpMethod = "POST"

		let requestContents: NSMutableDictionary = [ "receipt-data" : receipt ]
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
		let task = URLSession.shared.dataTask(with: storeRequest as URLRequest) { data, response, error -> Void in

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
					let sandboxValidator = AppleReceiptValidator(service: .sandbox)
					sandboxValidator.validate(receipt: receipt, password: autoRenewPassword, completion: completion)
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
}
