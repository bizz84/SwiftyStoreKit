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

class InAppProductQueryRequest: NSObject, SKProductsRequestDelegate {

    typealias RequestCallback = (result: SwiftyStoreKit.RetrieveResults) -> ()
    private let callback: RequestCallback
    private let request: SKProductsRequest
    // http://stackoverflow.com/questions/24011575/what-is-the-difference-between-a-weak-reference-and-an-unowned-reference
    deinit {
        request.delegate = nil
    }
    private init(productIds: Set<String>, callback: RequestCallback) {
        
        self.callback = callback
        request = SKProductsRequest(productIdentifiers: productIds)
        super.init()
        request.delegate = self
    }
    
    class func startQuery(productIds: Set<String>, callback: RequestCallback) -> InAppProductQueryRequest {
        let request = InAppProductQueryRequest(productIds: productIds, callback: callback)
        request.start()
        return request
    }

    func start() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.request.start()
        }
    }
    func cancel() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.request.cancel()
        }
    }
    
    // MARK: SKProductsRequestDelegate
    func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        
        dispatch_async(dispatch_get_main_queue()) {
            
            let retrievedProducts = Set<SKProduct>(response.products ?? [])
            let invalidProductIDs = Set<String>(response.invalidProductIdentifiers ?? [])
            self.callback(result: SwiftyStoreKit.RetrieveResults(retrievedProducts: retrievedProducts,
                invalidProductIDs: invalidProductIDs, error: nil))
        }
    }
    
    func requestDidFinish(request: SKRequest) {
        
    }
    // MARK: - missing SKPaymentTransactionState on OSX
    #if os(iOS) || os(tvOS)
    func request(request: SKRequest, didFailWithError error: NSError) {
        requestFailed(error)
    }
    #elseif os(OSX)
    func request(request: SKRequest, didFailWithError error: NSError) {
        requestFailed(error)
    }
    #endif
    func requestFailed(error: NSError){
        dispatch_async(dispatch_get_main_queue()) {
            self.callback(result: SwiftyStoreKit.RetrieveResults(retrievedProducts: [],
                invalidProductIDs: [], error: error))
        }
    }
}
