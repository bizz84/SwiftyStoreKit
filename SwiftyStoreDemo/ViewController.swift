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
            
            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }
    
    func purchase(no: String) {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.purchaseProduct(AppBundleId + ".purchase" + no) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            self.showAlert(self.alertForPurchaseResult(result))
        }
    }
    @IBAction func restorePurchases() {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.restorePurchases() { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            self.showAlert(self.alertForRestorePurchases(result))
        }
    }

    @IBAction func verifyReceipt() {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.verifyReceipt() { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForVerifyReceipt(result))

            switch result {
            case .Error(let error):
                switch (error) {
                case .NoReceiptData :
                    self.refreshReceipt()
                default: break
                }
            default: break
            }

        }
    }

    func refreshReceipt() {
        SwiftyStoreKit.refreshReceipt { (result) -> () in

            self.showAlert(self.alertForRefreshReceipt(result))

        }
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}

// MARK: User facing alerts
extension ViewController {
    
    func alertWithTitle(title: String, message: String) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
        return alert
    }
    
    func showAlert(alert: UIAlertController) {
        guard let _ = self.presentedViewController else {
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
    }

    func alertForProductRetrievalInfo(result: SwiftyStoreKit.RetrieveResultType) -> UIAlertController {
        
        switch result {
        case .Success(let product):
            let priceString = NSNumberFormatter.localizedStringFromNumber(product.price, numberStyle: .CurrencyStyle)
            return alertWithTitle(product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
        case .Error(let error):
            return alertWithTitle("Could not retrieve product info", message: String(error))
        }
    }

    func alertForPurchaseResult(result: SwiftyStoreKit.PurchaseResultType) -> UIAlertController {
        switch result {
        case .Success(let productId):
            print("Purchase Success: \(productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .NoProductIdentifier:
            return alertWithTitle("Purchase failed", message: "Product not found")
        case .PaymentNotAllowed:
            return alertWithTitle("Payments not enabled", message: "You are not allowed to make payments")
        case .Error(let error):
            print("Purchase Failed: \(error)")
            if case ResponseError.RequestFailed(let internalError) = error where internalError.domain == SKErrorDomain {
                return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
            }
            if (error as NSError).domain == SKErrorDomain {
                return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
            }
            return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
        }
    }
    
    func alertForRestorePurchases(result: SwiftyStoreKit.RestoreResultType) -> UIAlertController {
        
        switch result {
        case .Success(let productId):
            print("Restore Success: \(productId)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        case .NothingToRestore:
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        case .Error(let error):
            print("Restore Failed: \(error)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        }
    }


    func alertForVerifyReceipt(result: SwiftyStoreKit.VerifyReceiptResultType) -> UIAlertController{

        switch result {
        case .Success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return alertWithTitle("Receipt verified", message: "Receipt verified remotly")
        case .Error(let error):
            print("Verify receipt Failed: \(error)")
            switch (error) {
            case .NoReceiptData :
                return alertWithTitle("Receipt verification", message: "No receipt data, application will try to get a new one. Try again.")
            default:
                return alertWithTitle("Receipt verification", message: "Receipt verification failed")
            }
        }

    }

    func alertForRefreshReceipt(result: SwiftyStoreKit.RefreshReceiptResultType) -> UIAlertController {
        switch result {
        case .Success:
            print("Receipt refreshed Success")
            return self.alertWithTitle("Receipt refreshed", message: "Receipt refreshed with success")
        case .Error(let error):
            print("Receipt refreshed Failed: \(error)")
            return self.alertWithTitle("Receipt refreshed Failed", message: "Receipt refreshed Failed")
        }
    }

}

