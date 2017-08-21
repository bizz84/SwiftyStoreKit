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

    struct InAppProductQuery {
        let request: InAppProductQueryRequest
        var completionHandlers: [InAppProductRequestCallback]
    }
    
    let inAppProductRetriever: InAppProductRetriever
    init(inAppProductRetriever: InAppProductRetriever = InAppProductQueryRetriever()) {
        self.inAppProductRetriever = inAppProductRetriever
    }
    
    // As we can have multiple inflight queries and purchases, we store them in a dictionary by product id
    private var inflightQueries: [Set<String>: InAppProductQuery] = [:]

    func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) {

        if inflightQueries[productIds] == nil {
            let request = self.inAppProductRetriever.retrieveProducts(productIds: productIds) { results in
                
                if let query = self.inflightQueries[productIds] {
                    for completion in query.completionHandlers {
                        completion(results)
                    }
                    self.inflightQueries[productIds] = nil
                }
            }
            inflightQueries[productIds] = InAppProductQuery(request: request, completionHandlers: [completion])
        } else {
            inflightQueries[productIds]!.completionHandlers.append(completion)
        }
    }
}
