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
    
    @IBAction func purchase1() {
        purchase("1")
    }
    @IBAction func purchase2() {
        purchase("2")
    }
    @IBAction func purchase3() {
        purchase("3")
    }
    func purchase(no: String) {
        
        SwiftyStoreKit.sharedInstance.purchaseProduct(AppBundleId + ".purchase" + no) { result in
            
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
        
        SwiftyStoreKit.sharedInstance.restorePurchases() { result in
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

}

