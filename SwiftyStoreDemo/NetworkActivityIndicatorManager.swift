//
//  NetworkActivityIndicatorManager.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 28/09/2015.
//  Copyright © 2015 musevisions. All rights reserved.
//

import UIKit

class NetworkActivityIndicatorManager: NSObject {

    private static var loadingCount = 0
    
    class func networkOperationStarted() {
        
        if loadingCount == 0 {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        }
        loadingCount++
    }
    
    class func networkOperationFinished() {
        if loadingCount > 0 {
            loadingCount--
        }
        if loadingCount == 0 {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
}
