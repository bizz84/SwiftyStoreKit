//
//  SwiftyStoreKit.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 01/09/2015.
//  Copyright © 2015 musevisions. All rights reserved.
//

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
    public enum RestoreResultType {
        case Success(productId: String)
        case Error(error: ErrorType)
        case NothingToRestore
    }

    // MARK: Singleton
    public static let sharedInstance = SwiftyStoreKit()
    
    public var canMakePayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    // MARK: Public methods
    public func purchaseProduct(productId: String, completion: (result: PurchaseResultType) -> ()) {
        
        guard let product = store.products[productId] else {

            requestProduct(productId) { (inner: () throws -> SKProduct) -> () in
                do {
                    let product = try inner()
                    self.purchase(product: product, completion: completion)
                }
                catch let error {
                    completion(result: .Error(error: error))
                }
            }
            return
        }
        purchase(product: product, completion: completion)
    }
    
    public func restorePurchases(completion: (result: RestoreResultType) -> ()) {

        restoreRequest = InAppProductPurchaseRequest.restorePurchases() { result in
        
            self.restoreRequest = nil
            let returnValue = self.processRestoreResult(result)
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

    private func processPurchaseResult(result: InAppProductPurchaseRequest.ResultType) -> PurchaseResultType {
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
    
    private func processRestoreResult(result: InAppProductPurchaseRequest.ResultType) -> RestoreResultType {
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
