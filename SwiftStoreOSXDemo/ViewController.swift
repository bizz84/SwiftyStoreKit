//
//  ViewController.swift
//  SwiftStoreOSXDemo
//
//  Created by phimage on 22/12/15.
//  Copyright © 2015 musevisions. All rights reserved.
//

import Cocoa
import StoreKit
import SwiftyStoreKit

class ViewController: NSViewController {

    let AppBundleId = "com.musevisions.OSX.SwiftyStoreKit"
    
    // MARK: actions
    @IBAction func getInfo1(sender: AnyObject?) {
        getInfo("1")
    }
    @IBAction func getInfo2(sender: AnyObject!) {
        getInfo("2")
    }
    @IBAction func purchase1(sender: AnyObject!) {
        purchase("1")
    }
    @IBAction func purchase2(sender: AnyObject!) {
        purchase("2")
    }
    func getInfo(no: String) {

        SwiftyStoreKit.retrieveProductInfo(AppBundleId + ".purchase" + no) { result in

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(no: String) {

        SwiftyStoreKit.purchaseProduct(AppBundleId + ".purchase" + no) { result in

            self.showAlert(self.alertForPurchaseResult(result))
        }
    }
    
    @IBAction func restorePurchases(sender: AnyObject?) {

        SwiftyStoreKit.restorePurchases() { result in
            
            self.showAlert(self.alertForRestorePurchases(result))
        }
    }

}

// MARK: User facing alerts
extension ViewController {
    
    func alertWithTitle(title: String, message: String) -> NSAlert {
        
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = NSAlertStyle.InformationalAlertStyle
        return alert
    }
    func showAlert(alert: NSAlert) {
        
        if let window = NSApplication.sharedApplication().keyWindow {
            alert.beginSheetModalForWindow(window) { (response: NSModalResponse) in
            }
        } else {
            alert.runModal()
        }
    }
    
    func alertForProductRetrievalInfo(result: SwiftyStoreKit.RetrieveResultType) -> NSAlert {
        
        switch result {
        case .Success(let product):
            let priceString = NSNumberFormatter.localizedStringFromNumber(product.price ?? 0, numberStyle: .CurrencyStyle)
            return alertWithTitle(product.localizedTitle ?? "no title", message: "\(product.localizedDescription) - \(priceString)")
        case .Error(let error):
            return alertWithTitle("Could not retrieve product info", message: String(error))
        }
    }
    
    func alertForPurchaseResult(result: SwiftyStoreKit.PurchaseResultType) -> NSAlert {

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
    
    func alertForRestorePurchases(result: SwiftyStoreKit.RestoreResultType) -> NSAlert {
        
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
}
