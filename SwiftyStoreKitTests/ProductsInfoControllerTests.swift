//
//  ProductsInfoControllerTests.swift
// SwiftyStoreKit
//
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
import Foundation
@testable import SwiftyStoreKit

class TestInAppProductRequest: InAppProductRequest {
    
    private let productIds: Set<String>
    private let callback: InAppProductRequestCallback

    init(productIds: Set<String>, callback: @escaping InAppProductRequestCallback) {
        self.productIds = productIds
        self.callback = callback
    }
    
    func start() {

    }
    func cancel() {
        
    }
    
    func fireCallback() {
        callback(RetrieveResults(retrievedProducts: [], invalidProductIDs: [], error: nil))
    }
}

class TestInAppProductRequestBuilder: InAppProductRequestBuilder {
    
    var requests: [ TestInAppProductRequest ] = []
    var os_unfair_lock_s = os_unfair_lock()
    
    func request(productIds: Set<String>, callback: @escaping InAppProductRequestCallback) -> InAppProductRequest {
        os_unfair_lock_lock(&self.os_unfair_lock_s)
        defer {
          os_unfair_lock_unlock(&self.os_unfair_lock_s)
        }
      
        let request = TestInAppProductRequest(productIds: productIds, callback: callback)
        requests.append(request)
        return request
    }
    
    func fireCallbacks() {
        requests.forEach {
            $0.fireCallback()
        }
        requests = []
    }
}

class ProductsInfoControllerTests: XCTestCase {
    
    let sampleProductIdentifiers: Set<String> = ["com.iap.purchase1"]
    let testProducts: Set<String> = ["com.iap.purchase01",
                                     "com.iap.purchase02",
                                     "com.iap.purchase03",
                                     "com.iap.purchase04",
                                     "com.iap.purchase05",
                                     "com.iap.purchase06",
                                     "com.iap.purchase07",
                                     "com.iap.purchase08",
                                     "com.iap.purchase09",
                                     "com.iap.purchase10"]

    func testRetrieveProductsInfo_when_calledOnce_then_completionCalledOnce() {
        
        let requestBuilder = TestInAppProductRequestBuilder()
        let productInfoController = ProductsInfoController(inAppProductRequestBuilder: requestBuilder)
        
        var completionCount = 0
        productInfoController.retrieveProductsInfo(sampleProductIdentifiers) { _ in
            completionCount += 1
        }
        requestBuilder.fireCallbacks()
        
        XCTAssertEqual(completionCount, 1)
    }

    func testRetrieveProductsInfo_when_calledTwiceConcurrently_then_eachCompletionCalledOnce() {
        
        let requestBuilder = TestInAppProductRequestBuilder()
        let productInfoController = ProductsInfoController(inAppProductRequestBuilder: requestBuilder)
        
        var completionCount = 0
        productInfoController.retrieveProductsInfo(sampleProductIdentifiers) { _ in
            completionCount += 1
        }
        productInfoController.retrieveProductsInfo(sampleProductIdentifiers) { _ in
            completionCount += 1
        }
        requestBuilder.fireCallbacks()

        XCTAssertEqual(completionCount, 2)
    }
    func testRetrieveProductsInfo_when_calledTwiceNotConcurrently_then_eachCompletionCalledOnce() {
        
        let requestBuilder = TestInAppProductRequestBuilder()
        let productInfoController = ProductsInfoController(inAppProductRequestBuilder: requestBuilder)
        
        var completionCount = 0
        productInfoController.retrieveProductsInfo(sampleProductIdentifiers) { _ in
            completionCount += 1
        }
        requestBuilder.fireCallbacks()
        XCTAssertEqual(completionCount, 1)
        
        productInfoController.retrieveProductsInfo(sampleProductIdentifiers) { _ in
            completionCount += 1
        }
        requestBuilder.fireCallbacks()
        XCTAssertEqual(completionCount, 2)
    }
  
  func testRetrieveProductsInfo_when_calledConcurrentlyInDifferentThreads_then_eachcompletionCalledOnce_noCrashes() {
    let requestBuilder = TestInAppProductRequestBuilder()
    let productInfoController = ProductsInfoController(inAppProductRequestBuilder: requestBuilder)
    
    var completionCalledSet: Set<String> = []
    
    let expectation = XCTestExpectation(description: "Expect downloads of product informations")
    let group = DispatchGroup()
    
    for product in testProducts {
      DispatchQueue.global().async {
        group.enter()
        productInfoController.retrieveProductsInfo([product]) { _ in
          completionCalledSet.insert(product)
          group.leave()
        }
      }
    }
    
    group.notify(queue: DispatchQueue.global()) {
      expectation.fulfill()
    }
    
    XCTAssertEqual(completionCalledSet, testProducts)
  }
}
