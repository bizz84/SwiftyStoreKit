//
// SwiftyStoreKit.swift
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

import UIKit
import Foundation
import StoreKit


public class SwiftyStoreKit {

    // MARK: Private declarations
    private class InAppPurchaseStore {
        var products: [String: SKProduct] = [:]
        func addProduct(product: SKProduct) {
            products[product.productIdentifier] = product
        }
    }
    private var store: InAppPurchaseStore = InAppPurchaseStore()

    // As we can have multiple inflight queries and purchases, we store them in a dictionary by product id
    private var inflightQueries: [String: InAppProductQueryRequest] = [:]
    private var inflightPurchases: [String: InAppProductPurchaseRequest] = [:]
    private var restoreRequest: InAppProductPurchaseRequest?

    // MARK: Enums
    public enum PurchaseResultType {
        case Success(productId: String)
        case Error(error: ErrorType)
    }
    public enum RetrieveResultType {
        case Success(product: SKProduct)
        case Error(error: ErrorType)
    }
    public enum RestoreResultType {
        case Success(productId: String)
        case Error(error: ErrorType)
        case NothingToRestore
    }

    // MARK: Singleton
    private static let sharedInstance = SwiftyStoreKit()
    
    public class var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    // MARK: Public methods
    public class func retrieveProductInfo(productId: String, completion: (result: RetrieveResultType) -> ()) {
        guard let product = sharedInstance.store.products[productId] else {
            
            sharedInstance.requestProduct(productId) { (inner: () throws -> SKProduct) -> () in
                do {
                    let product = try inner()
                    completion(result: .Success(product: product))
                }
                catch let error {
                    completion(result: .Error(error: error))
                }
            }
            return
        }
        completion(result: .Success(product: product))
    }
    
    public class func purchaseProduct(productId: String, completion: (result: PurchaseResultType) -> ()) {
        
        if let product = sharedInstance.store.products[productId] {
            sharedInstance.purchase(product: product, completion: completion)
        }
        else {
            retrieveProductInfo(productId) { (result) -> () in
                if case .Success(let product) = result {
                    sharedInstance.purchase(product: product, completion: completion)
                }
                else if case .Error(let error) = result {
                    completion(result: .Error(error: error))
                }
            }
        }
    }
    
    public class func restorePurchases(completion: (result: RestoreResultType) -> ()) {

        sharedInstance.restoreRequest = InAppProductPurchaseRequest.restorePurchases() { result in
        
            sharedInstance.restoreRequest = nil
            let returnValue = sharedInstance.processRestoreResult(result)
            completion(result: returnValue)
        }
    }

    // MARK: private methods
    private func purchase(product product: SKProduct, completion: (result: PurchaseResultType) -> ()) {
    
        inflightPurchases[product.productIdentifier] = InAppProductPurchaseRequest.startPayment(product) { result in

            self.inflightPurchases[product.productIdentifier] = nil
            let returnValue = self.processPurchaseResult(result)
            completion(result: returnValue)
        }
    }

    private func processPurchaseResult(result: InAppProductPurchaseRequest.TransactionResult) -> PurchaseResultType {
        switch result {
        case .Purchased(let productId):
            // TODO: Need a way to match with current product?
            return .Success(productId: productId)
        case .Failed(let error):
            return .Error(error: error)
        case .Restored(_):
            fatalError("case Restored is not allowed for purchase flow")
        case .NothingToRestore:
            fatalError("case NothingToRestore is not allowed for purchase flow")
        }
    }
    
    private func processRestoreResult(result: InAppProductPurchaseRequest.TransactionResult) -> RestoreResultType {
        switch result {
        case .Purchased(_):
            fatalError("case Purchased is not allowed for restore flow")
        case .Failed(let error):
            return .Error(error: error)
        case .Restored(let productId):
            return .Success(productId: productId)
        case .NothingToRestore:
            return .NothingToRestore
        }
    }
    
    // http://appventure.me/2015/06/19/swift-try-catch-asynchronous-closures/
    private func requestProduct(productId: String, completion: (result: (() throws -> SKProduct)) -> ()) -> () {
        
        inflightQueries[productId] = InAppProductQueryRequest.startQuery([productId]) { result in
        
            self.inflightQueries[productId] = nil
            if case .Success(let products) = result {
                
                // Add to Store
                for product in products {
                    //print("Received product with ID: \(product.productIdentifier)")
                    self.store.addProduct(product)
                }
                guard let product = self.store.products[productId] else {
                    completion(result: { throw ResponseError.NoProducts })
                    return
                }
                completion(result: { return product })
            }
            else if case .Error(let error) = result {
                
                completion(result: { throw error })
            }
        }
    }
}
