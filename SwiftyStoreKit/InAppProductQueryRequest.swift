//
//  InAppPurchaseProductRequest.swift
//  WordShooter
//
//  Created by Andrea Bizzotto on 01/09/2015.
//  Copyright © 2015 musevisions. All rights reserved.
//

import UIKit
import StoreKit

public enum ResponseError : ErrorType {
    case InvalidProducts(invalidProductIdentifiers: [String])
    case NoProducts
    case RequestFailed(error: NSError)
}
public class InAppProductQueryRequest: NSObject, SKProductsRequestDelegate {

    enum ResultType {
        case Success(products: [SKProduct])
        case Error(e: ResponseError)
    }

    typealias RequestCallback = (result: ResultType) -> ()
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

    public func start() {
        dispatch_async(dispatch_get_global_queue(0, 0), {
            self.request.start()
        })
    }
    public func cancel() {
        dispatch_async(dispatch_get_global_queue(0, 0), {
            self.request.cancel()
        })
    }
    
    // MARK: SKProductsRequestDelegate
    public func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
        
        if response.invalidProductIdentifiers.count > 0 {
            let error = ResponseError.InvalidProducts(invalidProductIdentifiers: response.invalidProductIdentifiers)
            dispatch_async(dispatch_get_main_queue(), {
                self.callback(result: .Error(e: error))
            })
            return
        }
        if response.products.count == 0 {
            let error = ResponseError.NoProducts
            dispatch_async(dispatch_get_main_queue(), {
                self.callback(result: .Error(e: error))
            })
            return
        }
        callback(result: .Success(products: response.products))
    }
    
    public func requestDidFinish(request: SKRequest) {
        
    }
    public func request(request: SKRequest, didFailWithError error: NSError) {
        
        let error = ResponseError.RequestFailed(error: error)
        dispatch_async(dispatch_get_main_queue(), {
            self.callback(result: .Error(e: error))
        })
    }
}
