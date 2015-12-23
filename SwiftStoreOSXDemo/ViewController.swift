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

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func showMessage(title: String, message: String, handler: ((NSModalResponse) -> Void)? = nil) {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = NSAlertStyle.InformationalAlertStyle
        if let window = NSApplication.sharedApplication().keyWindow {
            alert.beginSheetModalForWindow(window) { (response: NSModalResponse) in
                handler?(response)
            }
        } else {
            let response = alert.runModal()
            handler?(response)
        }
        return
    }
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

            switch result {
            case .Success(let product):
                let priceString = NSNumberFormatter.localizedStringFromNumber(product.price ?? 0, numberStyle: .CurrencyStyle)
                self.showMessage(product.localizedTitle ?? "no title", message: "\(product.localizedDescription) - \(priceString)")
                break
            case .Error(let error):
                self.showMessage("Could not retrieve product info", message: String(error))
                break
            }
        }
    }

    func purchase(no: String) {

        SwiftyStoreKit.purchaseProduct(AppBundleId + ".purchase" + no) { result in

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

    @IBAction func restorePurchases(sender: AnyObject?) {

        SwiftyStoreKit.restorePurchases() { result in
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

    @IBAction func verifyReceipt(ender: AnyObject?) {

        SwiftyStoreKit.verifyReceipt() { result in
            switch result {
            case .Success(let receipt):
                self.showMessage("Receipt verified", message: "Receipt verified remotly")
                print("Verify receipt Success: \(receipt)")
                break
            case .Error(let error):
                print("Verify receipt Failed: \(error)")
                self.showMessage("Receipt verification failed", message: "The application will exit to create receipt data. You must have signed the application for app store with your developper id to test") { response in
                    exit(ReceiptExitCode.NotValid.rawValue)
                }
                break
            }
        }
    }

}

