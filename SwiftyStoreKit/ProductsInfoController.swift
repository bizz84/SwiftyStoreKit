//
// ProductsInfoController.swift
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

import Foundation
import StoreKit

class ProductsInfoController: NSObject {

    // MARK: Private declarations

    // As we can have multiple inflight queries and purchases, we store them in a dictionary by product id
    private var inflightQueries: [Set<String>: InAppProductQueryRequest] = [:]

    private(set) var products: [String: SKProduct] = [:]

    private func addProduct(_ product: SKProduct) {
        products[product.productIdentifier] = product
    }

    private func allProductsMatching(_ productIds: Set<String>) -> Set<SKProduct> {

        return Set(productIds.flatMap { self.products[$0] })
    }

    private func requestProducts(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) {

        inflightQueries[productIds] = InAppProductQueryRequest.startQuery(productIds) { result in

            self.inflightQueries[productIds] = nil
            for product in result.retrievedProducts {
                self.addProduct(product)
            }
            completion(result)
        }
    }

    func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) {

        let products = allProductsMatching(productIds)
        guard products.count == productIds.count else {

            requestProducts(productIds, completion: completion)
            return
        }
        completion(RetrieveResults(retrievedProducts: products, invalidProductIDs: [], error: nil))
    }

}
