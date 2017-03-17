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

enum RegisteredPurchase: String {

    case purchase1
    case purchase2
    case nonConsumablePurchase
    case consumablePurchase
    case autoRenewablePurchase
    case nonRenewingPurchase
}

class ViewController: UIViewController {

    let appBundleId = "com.musevisions.iOS.SwiftyStoreKit"

    let purchase1Suffix = RegisteredPurchase.purchase1
    let purchase2Suffix = RegisteredPurchase.autoRenewablePurchase

    // MARK: actions
    @IBAction func getInfo1() {
        getInfo(purchase1Suffix)
    }
    @IBAction func purchase1() {
        purchase(purchase1Suffix)
    }
    @IBAction func verifyPurchase1() {
        verifyPurchase(purchase1Suffix)
    }
    @IBAction func getInfo2() {
        getInfo(purchase2Suffix)
    }
    @IBAction func purchase2() {
        purchase(purchase2Suffix)
    }
    @IBAction func verifyPurchase2() {
        verifyPurchase(purchase2Suffix)
    }

    func getInfo(_ purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.retrieveProductsInfo([appBundleId + "." + purchase.rawValue]) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }

    func purchase(_ purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.purchaseProduct(appBundleId + "." + purchase.rawValue, atomically: true) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            if case .success(let product) = result {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            if let alert = self.alertForPurchaseResult(result) {
                self.showAlert(alert)
            }
        }
    }

    @IBAction func restorePurchases() {

        NetworkActivityIndicatorManager.networkOperationStarted()
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            NetworkActivityIndicatorManager.networkOperationFinished()

            for product in results.restoredProducts {
                // Deliver content from server, then:
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }

    @IBAction func verifyReceipt() {

        NetworkActivityIndicatorManager.networkOperationStarted()
		let appleValidator = AppleReceiptValidator(service: .production)
		SwiftyStoreKit.verifyReceipt(using: appleValidator, password: "your-shared-secret") { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            self.showAlert(self.alertForVerifyReceipt(result))

            if case .error(let error) = result {
                if case .noReceiptData = error {
                    self.refreshReceipt()
                }
            }
        }
    }

    func verifyPurchase(_ purchase: RegisteredPurchase) {

        NetworkActivityIndicatorManager.networkOperationStarted()
		let appleValidator = AppleReceiptValidator(service: .production)
		SwiftyStoreKit.verifyReceipt(using: appleValidator, password: "your-shared-secret") { result in
            NetworkActivityIndicatorManager.networkOperationFinished()

            switch result {
            case .success(let receipt):

                let productId = self.appBundleId + "." + purchase.rawValue

                switch purchase {
                case .autoRenewablePurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        type: .autoRenewable,
                        productId: productId,
                        inReceipt: receipt,
                        validUntil: Date()
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                case .nonRenewingPurchase:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        type: .nonRenewing(validDuration: 60),
                        productId: productId,
                        inReceipt: receipt,
                        validUntil: Date()
                    )
                    self.showAlert(self.alertForVerifySubscription(purchaseResult))
                default:
                    let purchaseResult = SwiftyStoreKit.verifyPurchase(
                        productId: productId,
                        inReceipt: receipt
                    )
                    self.showAlert(self.alertForVerifyPurchase(purchaseResult))
                }

            case .error(let error):
                self.showAlert(self.alertForVerifyReceipt(result))
                if case .noReceiptData = error {
                    self.refreshReceipt()
                }
            }
        }
    }

    func refreshReceipt() {

        SwiftyStoreKit.refreshReceipt { result in

            self.showAlert(self.alertForRefreshReceipt(result))
        }
    }

#if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
#endif
}

// MARK: User facing alerts
extension ViewController {

    func alertWithTitle(_ title: String, message: String) -> UIAlertController {

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        return alert
    }

    func showAlert(_ alert: UIAlertController) {
        guard let _ = self.presentedViewController else {
            self.present(alert, animated: true, completion: nil)
            return
        }
    }

    func alertForProductRetrievalInfo(_ result: RetrieveResults) -> UIAlertController {

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

    func alertForPurchaseResult(_ result: PurchaseResult) -> UIAlertController? {
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
            case .storeProductNotAvailable: // Product is not available in the current storefront
                return alertWithTitle("Purchase failed", message: "The product is not available in the current storefront")
            case .cloudServicePermissionDenied: // user has not allowed access to cloud service information
                return alertWithTitle("Purchase failed", message: "Access to cloud service information is not allowed")
            case .cloudServiceNetworkConnectionFailed: // the device could not connect to the nework
                return alertWithTitle("Purchase failed", message: "Could not connect to the network")
            }
        }
    }

    func alertForRestorePurchases(_ results: RestoreResults) -> UIAlertController {

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

    func alertForVerifyReceipt(_ result: VerifyReceiptResult) -> UIAlertController {

        switch result {
        case .success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return alertWithTitle("Receipt verified", message: "Receipt verified remotly")
        case .error(let error):
            print("Verify receipt Failed: \(error)")
            switch error {
            case .noReceiptData :
                return alertWithTitle("Receipt verification", message: "No receipt data, application will try to get a new one. Try again.")
            default:
                return alertWithTitle("Receipt verification", message: "Receipt verification failed")
            }
        }
    }

    func alertForVerifySubscription(_ result: VerifySubscriptionResult) -> UIAlertController {

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

    func alertForVerifyPurchase(_ result: VerifyPurchaseResult) -> UIAlertController {

        switch result {
        case .purchased:
            print("Product is purchased")
            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .notPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }

    func alertForRefreshReceipt(_ result: RefreshReceiptResult) -> UIAlertController {
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
