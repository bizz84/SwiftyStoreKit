//
//  ViewController.swift
//  SwiftyStoreKit
//
//  Created by Andrea Bizzotto on 03/09/2015.
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
import StoreKit
import SwiftyStoreKit

enum RegisteredPurchase : String {
    
    case Purchase1 = "purchase1"
    case Purchase2 = "purchase2"
    case NonConsumablePurchase = "nonConsumablePurchase"
    case ConsumablePurchase = "consumablePurchase"
    case AutoRenewablePurchase = "autoRenewablePurchase"
}


class ViewController: UIViewController {

    let AppBundleId = "com.musevisions.iOS.SwiftyStoreKit"
    
    let Purchase1 = RegisteredPurchase.Purchase1
    let Purchase2 = RegisteredPurchase.AutoRenewablePurchase
    
    // MARK: actions
    @IBAction func getInfo1() {
        getInfo(Purchase1)
    }
    @IBAction func purchase1() {
        purchase(Purchase1)
    }
    @IBAction func verifyPurchase1() {
        verifyPurchase(Purchase1)
    }
    @IBAction func getInfo2() {
        getInfo(Purchase2)
    }
    @IBAction func purchase2() {
        purchase(Purchase2)
    }
    @IBAction func verifyPurchase2() {
        verifyPurchase(Purchase2)
    }

    func getInfo(purchase: RegisteredPurchase) {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.retrieveProductsInfo([AppBundleId + "." + purchase.rawValue]) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }
    
    func purchase(purchase: RegisteredPurchase) {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.purchaseProduct(AppBundleId + "." + purchase.rawValue) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            self.showAlert(self.alertForPurchaseResult(result))
        }
    }
    @IBAction func restorePurchases() {
        
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.restorePurchases() { results in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt() {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.verifyReceipt() { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForVerifyReceipt(result))

            if case .Error(let error) = result {
                if case .NoReceiptData = error {
                    self.refreshReceipt()
                }
            }
        }
    }

    func verifyPurchase(purchase: RegisteredPurchase) {
     
        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.verifyReceipt() { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            switch result {
            case .Success(let receipt):
              
                // Specific behaviour for AutoRenewablePurchase
                if purchase == .AutoRenewablePurchase {
                    let purchaseResult = SwiftyStoreKit.verifyAutomaticallyRenewableSubscription(
                        productId: self.AppBundleId + "." + purchase.rawValue,
                        inReceipt: receipt,
                        validUntil: NSDate()
                    )
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }
                else {
                    let purchaseResult = SwiftyStoreKit.verifyPurchase(
                        productId: self.AppBundleId + "." + purchase.rawValue,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }
                
            case .Error(let error):
                self.showAlert(self.alertForVerifyReceipt(result))
                if case .NoReceiptData = error {
                    self.refreshReceipt()
                }
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

    func alertForProductRetrievalInfo(result: SwiftyStoreKit.RetrieveResults) -> UIAlertController {
        
        if let product = result.retrievedProducts.first {
            let priceString = NSNumberFormatter.localizedStringFromNumber(product.price, numberStyle: .CurrencyStyle)
            return alertWithTitle(product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
        }
        else if let invalidProductId = result.invalidProductIDs.first {
            return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
        }
        else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            return alertWithTitle("Could not retrieve product info", message: errorString)
        }
    }

    func alertForPurchaseResult(result: SwiftyStoreKit.PurchaseResult) -> UIAlertController {
        switch result {
        case .Success(let productId):
            print("Purchase Success: \(productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .Error(let error):
            print("Purchase Failed: \(error)")
            switch error {
                case .Failed(let error):
                    if error.domain == SKErrorDomain {
                        return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
                    }
                    return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
                case .InvalidProductId(let productId):
                    return alertWithTitle("Purchase failed", message: "\(productId) is not a valid product identifier")
                case .NoProductIdentifier:
                    return alertWithTitle("Purchase failed", message: "Product not found")
                case .PaymentNotAllowed:
                    return alertWithTitle("Payments not enabled", message: "You are not allowed to make payments")
            }
        }
    }
    
    func alertForRestorePurchases(results: SwiftyStoreKit.RestoreResults) -> UIAlertController {

        if results.restoreFailedProducts.count > 0 {
            print("Restore Failed: \(results.restoreFailedProducts)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        }
        else if results.restoredProductIds.count > 0 {
            print("Restore Success: \(results.restoredProductIds)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        }
        else {
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        }
    }


    func alertForVerifyReceipt(result: SwiftyStoreKit.VerifyReceiptResult) -> UIAlertController {

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
  
    func alertForVerifyPurchase(result: SwiftyStoreKit.VerifyAutomaticallyRenewableSubscriptionResult) -> UIAlertController {
    
        switch result {
        case .Purchased(let expiresDate):
            print("Product is valid until \(expiresDate)")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiresDate)")
        case .Expired(let expiresDate):
            print("Product is expired since \(expiresDate)")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiresDate)")
        case .NotPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForVerifyPurchase(result: SwiftyStoreKit.VerifyPurchaseResult) -> UIAlertController {
        
        switch result {
        case .Purchased:
            print("Product is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .NotPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForRefreshReceipt(result: SwiftyStoreKit.RefreshReceiptResult) -> UIAlertController {
        switch result {
        case .Success:
            print("Receipt refresh Success")
            return self.alertWithTitle("Receipt refreshed", message: "Receipt refreshed successfully")
        case .Error(let error):
            print("Receipt refresh Failed: \(error)")
            return self.alertWithTitle("Receipt refresh failed", message: "Receipt refresh failed")
        }
    }

}

