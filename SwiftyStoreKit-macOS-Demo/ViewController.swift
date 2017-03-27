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

enum RegisteredPurchase: String {

    case purchase1
    case purchase2
    case nonConsumablePurchase
    case consumablePurchase
    case autoRenewablePurchase
    case nonRenewingPurchase

}

class ViewController: NSViewController {

    let appBundleId = "com.musevisions.MacOS.SwiftyStoreKitDemo"

    let purchase1Suffix = RegisteredPurchase.purchase1
    let purchase2Suffix = RegisteredPurchase.autoRenewablePurchase

    // MARK: actions
    @IBAction func getInfo1(_ sender: Any?) {
        getInfo(purchase1Suffix)
    }
    @IBAction func purchase1(_ sender: Any?) {
        purchase(purchase1Suffix)
    }
    @IBAction func verifyPurchase1(_ sender: Any?) {
        verifyPurchase(purchase1Suffix)
    }

    @IBAction func getInfo2(_ sender: Any?) {
        getInfo(purchase2Suffix)
    }
    @IBAction func purchase2(_ sender: Any?) {
        purchase(purchase2Suffix)
    }
    @IBAction func verifyPurchase2(_ sender: Any?) {
        verifyPurchase(purchase2Suffix)
    }

    func getInfo(_ purchase: RegisteredPurchase) {

        SwiftyStoreKit.retrieveProductsInfo([appBundleId + "." + purchase.rawValue]) { result in

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(_ purchase: RegisteredPurchase) {

        SwiftyStoreKit.purchaseProduct(appBundleId + "." + purchase.rawValue, atomically: true) { result in

            if case .success(let product) = result {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }

            if let errorAlert = self.alertForPurchaseResult(result) {
                self.showAlert(errorAlert)
            }
        }
    }

    @IBAction func restorePurchases(_ sender: Any?) {

        SwiftyStoreKit.restorePurchases(atomically: true) { results in

            for product in results.restoredProducts where product.needsFinishTransaction {
                // Deliver content from server, then:
                SwiftyStoreKit.finishTransaction(product.transaction)
            }

            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt(_ sender: Any?) {

        let appleValidator = AppleReceiptValidator(service: .production)
        SwiftyStoreKit.verifyReceipt(using: appleValidator, password: "your-shared-secret") { result in

            self.showAlert(self.alertForVerifyReceipt(result)) { _ in

                if case .error(let error) = result {
                    if case .noReceiptData = error {
                        self.refreshReceipt()
                    }
                }
            }
        }
    }

    func verifyPurchase(_ purchase: RegisteredPurchase) {

        let appleValidator = AppleReceiptValidator(service: .production)
        SwiftyStoreKit.verifyReceipt(using: appleValidator, password: "your-shared-secret") { result in

            switch result {
            case .success(let receipt):

                let productId = self.appBundleId + "." + purchase.rawValue

                switch purchase {
                case .autoRenewablePurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        type: .autoRenewable,
                        productId: productId,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                case .nonRenewingPurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        type: .nonRenewing(validDuration: 60),
                        productId: productId,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                default:
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

        SwiftyStoreKit.refreshReceipt { result in

            self.showAlert(self.alertForRefreshReceipt(result))
        }
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
            alert.beginSheetModal(for: window) { (response: NSModalResponse) in
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
        } else if let invalidProductId = result.invalidProductIDs.first {
            return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
        } else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            return alertWithTitle("Could not retrieve product info", message: errorString)
        }
    }

    func alertForPurchaseResult(_ result: PurchaseResult) -> NSAlert? {
        switch result {
        case .success(let product):
            print("Purchase Success: \(product.productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .error(let error):
            print("Purchase Failed: \(error)")
            switch error.code {
            case .unknown: return alertWithTitle("Purchase failed", message: "Unknown error. Please contact support")
            case .clientInvalid: // client is not allowed to issue the request, etc.
                return alertWithTitle("Purchase failed", message: "Not allowed to make the payment")
            case .paymentCancelled: // user cancelled the request, etc.
                return nil
            case .paymentInvalid: // purchase identifier was invalid, etc.
                return alertWithTitle("Purchase failed", message: "The purchase identifier was invalid")
            case .paymentNotAllowed: // this device is not allowed to make the payment
                return alertWithTitle("Purchase failed", message: "The device is not allowed to make the payment")
            }
        }
    }

    func alertForRestorePurchases(_ results: RestoreResults) -> NSAlert {

        if results.restoreFailedProducts.count > 0 {
            print("Restore Failed: \(results.restoreFailedProducts)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        } else if results.restoredProducts.count > 0 {
            print("Restore Success: \(results.restoredProducts)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        } else {
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
