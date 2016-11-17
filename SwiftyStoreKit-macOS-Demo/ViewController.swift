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

enum RegisteredPurchase : String {
    
    case purchase1 = "purchase1"
    case purchase2 = "purchase2"
    case nonConsumablePurchase = "nonConsumablePurchase"
    case consumablePurchase = "consumablePurchase"
    case autoRenewablePurchase = "autoRenewablePurchase"
    case nonRenewingPurchase = "nonRenewingPurchase"
    
}

class ViewController: NSViewController {

    let AppBundleId = "com.musevisions.MacOS.SwiftyStoreKitDemo"
    
    let Purchase1 = RegisteredPurchase.purchase1
    let Purchase2 = RegisteredPurchase.autoRenewablePurchase

    // MARK: actions
    @IBAction func getInfo1(_ sender: AnyObject?) {
        getInfo(Purchase1)
    }
    @IBAction func purchase1(_ sender: AnyObject?) {
        purchase(Purchase1)
    }
    @IBAction func verifyPurchase1(_ sender: AnyObject?) {
        verifyPurchase(Purchase1)
    }

    @IBAction func getInfo2(_ sender: AnyObject?) {
        getInfo(Purchase2)
    }
    @IBAction func purchase2(_ sender: AnyObject?) {
        purchase(Purchase2)
    }
    @IBAction func verifyPurchase2(_ sender: AnyObject?) {
        verifyPurchase(Purchase2)
    }

    func getInfo(_ purchase: RegisteredPurchase) {

        SwiftyStoreKit.retrieveProductsInfo([AppBundleId + "." + purchase.rawValue]) { result in

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(_ purchase: RegisteredPurchase) {

        SwiftyStoreKit.purchaseProduct(AppBundleId + "." + purchase.rawValue, atomically: true) { result in

            if case .success(let product) = result {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }

            self.showAlert(self.alertForPurchaseResult(result))
        }
    }

    @IBAction func restorePurchases(_ sender: AnyObject?) {

        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            
            for product in results.restoredProducts {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }

            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt(_ sender: AnyObject?) {

        SwiftyStoreKit.verifyReceipt(password: "your-shared-secret") { result in

            self.showAlert(self.alertForVerifyReceipt(result)) { response in

                self.refreshReceipt()
            }
        }
    }

    func verifyPurchase(_ purchase: RegisteredPurchase) {
        
        SwiftyStoreKit.verifyReceipt(password: "your-shared-secret") { result in
            
            switch result {
            case .success(let receipt):
                
                let productId = self.AppBundleId + "." + purchase.rawValue
                
                // Specific behaviour for AutoRenewablePurchase
                if purchase == .autoRenewablePurchase {
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        productId: productId,
                        inReceipt: receipt,
                        validUntil: Date()
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                }
                else {
                    let purchaseResult = SwiftyStoreKit.verifyPurchase(
                        productId: productId,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }
                            
            case .error(_):
                self.showAlert(self.alertForVerifyReceipt(result))
            }
        }
    }

    func refreshReceipt() {
        
        SwiftyStoreKit.refreshReceipt()
    }

}

// MARK: User facing alerts
extension ViewController {
    
    func alertWithTitle(_ title: String, message: String) -> NSAlert {
        
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = NSAlertStyle.informational
        return alert
    }
    func showAlert(_ alert: NSAlert, handler: ((NSModalResponse) -> Void)? = nil) {
        
        if let window = NSApplication.shared().keyWindow {
            alert.beginSheetModal(for: window)  { (response: NSModalResponse) in
                handler?(response)
            }
        } else {
            let response = alert.runModal()
            handler?(response)
        }
    }

    func alertForProductRetrievalInfo(_ result: RetrieveResults) -> NSAlert {
        
        if let product = result.retrievedProducts.first {
            let priceString = product.localizedPrice!
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
    
    func alertForPurchaseResult(_ result: PurchaseResult) -> NSAlert {

        switch result {
        case .success(let productId):
            print("Purchase Success: \(productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .error(let error):
            print("Purchase Failed: \(error)")
            switch error {
            case .failed(let error):
                if (error as NSError).domain == SKErrorDomain {
                    return alertWithTitle("Purchase failed", message: "Please check your Internet connection or try again later")
                }
                return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
            case .invalidProductId(let productId):
                return alertWithTitle("Purchase failed", message: "\(productId) is not a valid product identifier")
            case .noProductIdentifier:
                return alertWithTitle("Purchase failed", message: "Product not found")
            case .paymentNotAllowed:
                return alertWithTitle("Payments not enabled", message: "You are not allowed to make payments")
            }
        }
    }
    
    func alertForRestorePurchases(_ results: RestoreResults) -> NSAlert {
        
        if results.restoreFailedProducts.count > 0 {
            print("Restore Failed: \(results.restoreFailedProducts)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        }
        else if results.restoredProducts.count > 0 {
            print("Restore Success: \(results.restoredProducts)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        }
        else {
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        }
    }
    
    func alertForVerifyReceipt(_ result: VerifyReceiptResult) -> NSAlert {

        switch result {
        case .success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return self.alertWithTitle("Receipt verified", message: "Receipt verified remotly")
        case .error(let error):
            print("Verify receipt Failed: \(error)")
            return self.alertWithTitle("Receipt verification failed", message: "The application will exit to create receipt data. You must have signed the application with your developer id to test and be outside of XCode")
        }
    }
    
    func alertForVerifySubscription(_ result: VerifySubscriptionResult) -> NSAlert {
        
        switch result {
        case .purchased(let expiresDate):
            print("Product is valid until \(expiresDate)")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiresDate)")
        case .expired(let expiresDate):
            print("Product is expired since \(expiresDate)")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiresDate)")
        case .notPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }


    func alertForVerifyPurchase(_ result: VerifyPurchaseResult) -> NSAlert {
        
        switch result {
        case .purchased:
            print("Product is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .notPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }
    
    func alertForRefreshReceipt(_ result: RefreshReceiptResult) -> NSAlert {
        switch result {
        case .success(let receiptData):
            print("Receipt refresh Success: \(receiptData.base64EncodedString)")
            return alertWithTitle("Receipt refreshed", message: "Receipt refreshed successfully")
        case .error(let error):
            print("Receipt refresh Failed: \(error)")
            return alertWithTitle("Receipt refresh failed", message: "Receipt refresh failed")
        }
    }

}

