//
//  ViewController.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 03/09/2015.
//  Copyright © 2015 musevisions. All rights reserved.
//

import UIKit
import StoreKit
import SwiftyStoreKit

class ViewController: UIViewController {

    let AppBundleId = "com.musevisions.iOS.SwiftyStoreKit"
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func showMessage(title: String, message: String) {
        
        guard let _ = self.presentedViewController else {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
    }
    // MARK: actions
    @IBAction func getInfo1() {
        getInfo("1")
    }
    @IBAction func getInfo2() {
        getInfo("2")
    }
    @IBAction func purchase1() {
        purchase("1")
    }
    @IBAction func purchase2() {
        purchase("2")
    }
    func getInfo(no: String) {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.retrieveProductInfo(AppBundleId + ".purchase" + no) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            switch result {
            case .Success(let product):
                let priceString = NSNumberFormatter.localizedStringFromNumber(product.price, numberStyle: .CurrencyStyle)
                self.showMessage(product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
                break
            case .Error(let error):
                self.showMessage("Could not retrieve product info", message: (error as NSError).localizedDescription)
                break
            }
        }
    }
    
    func purchase(no: String) {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.purchaseProduct(AppBundleId + ".purchase" + no) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            switch result {
            case .Success(let productId):
                self.showMessage("Thank You", message: "Purchase completed")
                print("Purchase Success: \(productId)")
                break
            case .Error(let error):
                if case ResponseError.RequestFailed(let internalError) = error where internalError.domain == SKErrorDomain {
                    self.showMessage("Purchase failed", message: "Please check your Internet connection or try again later")
                }
                else if (error as NSError).domain == SKErrorDomain {
                    self.showMessage("Purchase failed", message: "Please check your Internet connection or try again later")
                }
                else {
                    self.showMessage("Purchase failed", message: "Unknown error. Please contact support")
                }
                print("Purchase Failed: \(error)")
                break
            }
        }
    }
    @IBAction func restorePurchases() {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.restorePurchases() { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            switch result {
            case .Success(let productId):
                self.showMessage("Purchases Restored", message: "All purchases have been restored")
                print("Restore Success: \(productId)")
                break
            case .NothingToRestore:
                self.showMessage("Nothing to restore", message: "No previous purchases were found")
                print("Nothing to Restore")
                break
            case .Error(let error):
                print("Restore Failed: \(error)")
                break
            }
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}

