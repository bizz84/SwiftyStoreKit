//
//  ViewController.swift
//  SwiftStoreOSXDemo
//
//  Created by phimage on 22/12/15.
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

        SwiftyStoreKit.restorePurchases() { results in
            
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt(ender: AnyObject?) {

        SwiftyStoreKit.verifyReceipt() { result in

            self.showAlert(self.alertForVerifyReceipt(result)) { response in

                SwiftyStoreKit.refreshReceipt()
            }
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
    func showAlert(alert: NSAlert, handler: ((NSModalResponse) -> Void)? = nil) {
        
        if let window = NSApplication.sharedApplication().keyWindow {
            alert.beginSheetModalForWindow(window)  { (response: NSModalResponse) in
                handler?(response)
            }
        } else {
            let response = alert.runModal()
            handler?(response)
        }
    }

    func alertForProductRetrievalInfo(result: SwiftyStoreKit.RetrieveResult) -> NSAlert {
        
        switch result {
        case .Success(let product):
            let priceString = NSNumberFormatter.localizedStringFromNumber(product.price ?? 0, numberStyle: .CurrencyStyle)
            return alertWithTitle(product.localizedTitle ?? "no title", message: "\(product.localizedDescription) - \(priceString)")
        case .Error(let error):
            return alertWithTitle("Could not retrieve product info", message: String(error))
        }
    }
    
    func alertForPurchaseResult(result: SwiftyStoreKit.PurchaseResult) -> NSAlert {

        switch result {
        case .Success(let productId):
            print("Purchase Success: \(productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .Error(let error):
            print("Purchase Failed: \(error)")
            switch error {
            case .Failed(let error):
                if case ResponseError.RequestFailed(let internalError) = error where internalError.domain == SKErrorDomain {
                    return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
                }
                if (error as NSError).domain == SKErrorDomain {
                    return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
                }
                return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
            case .NoProductIdentifier:
                return alertWithTitle("Purchase failed", message: "Product not found")
            case .PaymentNotAllowed:
                return alertWithTitle("Payments not enabled", message: "You are not allowed to make payments")
            }
        }
    }
    
    func alertForRestorePurchases(results: SwiftyStoreKit.RestoreResults) -> NSAlert {
        
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
    
    func alertForVerifyReceipt(result: SwiftyStoreKit.VerifyReceiptResult) -> NSAlert {

        switch result {
        case .Success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return self.alertWithTitle("Receipt verified", message: "Receipt verified remotly")
        case .Error(let error):
            print("Verify receipt Failed: \(error)")
            return self.alertWithTitle("Receipt verification failed", message: "The application will exit to create receipt data. You must have signed the application with your developer id to test and be outside of XCode")
        }
    }

}

