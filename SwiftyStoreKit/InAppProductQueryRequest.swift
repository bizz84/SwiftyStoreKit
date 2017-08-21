//
// InAppPurchaseProductRequest.swift
// SwiftyStoreKit
//
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

import StoreKit

typealias InAppProductRequestCallback = (RetrieveResults) -> Void

protocol InAppProductRequest: class {
    func start()
    func cancel()
}

class InAppProductQueryRequest: NSObject, InAppProductRequest, SKProductsRequestDelegate {

    private let callback: InAppProductRequestCallback
    private let request: SKProductsRequest

    deinit {
        request.delegate = nil
    }
    init(productIds: Set<String>, callback: @escaping InAppProductRequestCallback) {

        self.callback = callback
        request = SKProductsRequest(productIdentifiers: productIds)
        super.init()
        request.delegate = self
    }

    func start() {
        request.start()
    }
    func cancel() {
        request.cancel()
    }

    // MARK: SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {

        let retrievedProducts = Set<SKProduct>(response.products)
        let invalidProductIDs = Set<String>(response.invalidProductIdentifiers)
        performCallback(RetrieveResults(retrievedProducts: retrievedProducts,
            invalidProductIDs: invalidProductIDs, error: nil))
    }

    func requestDidFinish(_ request: SKRequest) {

    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        performCallback(RetrieveResults(retrievedProducts: Set<SKProduct>(), invalidProductIDs: Set<String>(), error: error))
    }
    
    private func performCallback(_ results: RetrieveResults) {
        DispatchQueue.main.async {
            self.callback(results)
        }
    }
}
