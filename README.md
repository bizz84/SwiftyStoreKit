# SwiftyStoreKit
SwiftyStoreKit is a lightweight In App Purchases framework for iOS 8.0+, tvOS 9.0+ and OS X 10.10+, written in Swift.

[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://mit-license.org)
[![Platform](http://img.shields.io/badge/platform-ios%20%7C%20macos%20%7C%20tvos-lightgrey.svg?style=flat)](https://developer.apple.com/resources/)
[![Language](https://img.shields.io/badge/swift-3.0-orange.svg)](https://developer.apple.com/swift)
[![Build](https://img.shields.io/travis/bizz84/SwiftyStoreKit.svg?style=flat)](https://travis-ci.org/bizz84/SwiftyStoreKit)
[![Issues](https://img.shields.io/github/issues/bizz84/SwiftyStoreKit.svg?style=flat)](https://github.com/bizz84/SwiftyStoreKit/issues)
[![Cocoapod](http://img.shields.io/cocoapods/v/SwiftyStoreKit.svg?style=flat)](http://cocoadocs.org/docsets/SwiftyStoreKit/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Twitter](https://img.shields.io/badge/twitter-@biz84-blue.svg?maxAge=2592000)](http://twitter.com/biz84)

#### NOTE: Master branch now compiles with Swift 3.0 under Xcode 8.

#### Swift 2.3 is supported in the [swift-2.3 branch](https://github.com/bizz84/SwiftyStoreKit/tree/swift-2.3).
#### Swift 2.2 / Xcode 7 compatibility is supported in the [swift-2.2 branch](https://github.com/bizz84/SwiftyStoreKit/tree/swift-2.2).

### Preview

<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview.png" width="320">
<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview2.png" width="320">

### Setup + Complete Transactions

Apple recommends to register a transaction observer [as soon as the app starts](https://developer.apple.com/library/ios/technotes/tn2387/_index.html):
> Adding your app's observer at launch ensures that it will persist during all launches of your app, thus allowing your app to receive all the payment queue notifications.

SwiftyStoreKit supports this by calling `completeTransactions()` when the app starts:

```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

	SwiftyStoreKit.completeTransactions() { completedTransactions in
	
	    for completedTransaction in completedTransactions {
	
	        if completedTransaction.transactionState == .Purchased || completedTransaction.transactionState == .Restored {
	
	            print("purchased: \(completedTransaction.productId)")
	        }
	    }
	}
  return true
}
```

If there are any pending transactions at this point, these will be reported by the completion block so that the app state and UI can be updated.

### Retrieve products info
```swift
SwiftyStoreKit.retrieveProductsInfo(["com.musevisions.SwiftyStoreKit.Purchase1"]) { result in
    if let product = result.retrievedProducts.first {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = product.priceLocale
        numberFormatter.numberStyle = .currency
        let priceString = numberFormatter.string(from: product.price)
        print("Product: \(product.localizedDescription), price: \(priceString)")
    }
    else if let invalidProductId = result.invalidProductIDs.first {
        return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
    }
    else {
	     print("Error: \(result.error)")
    }
}
```
### Purchase a product

```swift
SwiftyStoreKit.purchaseProduct("com.musevisions.SwiftyStoreKit.Purchase1") { result in
    switch result {
    case .success(let productId):
        print("Purchase Success: \(productId)")
    case .error(let error):
        print("Purchase Failed: \(error)")
    }
}
```

### Restore previous purchases

```swift
SwiftyStoreKit.restorePurchases() { results in
    if results.restoreFailedProducts.count > 0 {
        print("Restore Failed: \(results.restoreFailedProducts)")
    }
    else if results.restoredProductIds.count > 0 {
        print("Restore Success: \(results.restoredProductIds)")
    }
    else {
        print("Nothing to Restore")
    }
}
```

### Verify Receipt

```swift
SwiftyStoreKit.verifyReceipt() { result in
    if case .error(let error) = result {
        if case .noReceiptData = error {
            self.refreshReceipt()
        }
    }
}

func refreshReceipt() {
    SwiftyStoreKit.refreshReceipt { result in
        switch result {
        case .success:
            print("Receipt refresh success")
        case .error(let error):
            print("Receipt refresh failed: \(error)")
        }
    }
}
```

When using auto-renewable subscriptions, the shared secret can be specified like so:

```
SwiftyStoreKit.verifyReceipt(password: "your_shared_secret")
```

### Verify Purchase

```swift
SwiftyStoreKit.verifyReceipt() { result in
    switch result {
    case .success(let receipt):
        // Verify the purchase of Consumable or NonConsumable
        let purchaseResult = SwiftyStoreKit.verifyPurchase(
            productId: "com.musevisions.SwiftyStoreKit.Purchase1",
            inReceipt: receipt
        )
        switch purchaseResult {
        case .purchased(let expiresDate):
            print("Product is purchased.")
        case .notPurchased:
            print("The user has never purchased this product")
        }
    case .Error(let error):
        print("Receipt verification failed: \(error)")
    }
}
```

Note that for consumable products, the receipt will only include the information for a couples of minutes after the purchase.

### Verify Subscription

```swift
SwiftyStoreKit.verifyReceipt() { result in
    switch result {
    case .success(let receipt):
        // Verify the purchase of a Subscription
        let purchaseResult = SwiftyStoreKit.verifySubscription(
            productId: "com.musevisions.SwiftyStoreKit.Subscription",
            inReceipt: receipt,
            validUntil: NSDate(),
            validDuration: 3600 * 24 * 30 // Non Renewing Subscription only
        )
        switch purchaseResult {
        case .purchased(let expiresDate):
            print("Product is valid until \(expiresDate)")
        case .expired(let expiresDate):
            print("Product is expired since \(expiresDate)")
        case .notPurchased:
            print("The user has never purchased this product")
        }

    case .error(let error):
        print("Receipt verification failed: \(error)")
    }
}
```


To test the expiration of a Non Renewing Subscription, you must indicate the `validDuration` time interval in seconds.



**NOTE**:
The framework provides a simple block based API with robust error handling on top of the existing StoreKit framework. It does **NOT** persist in app purchases data locally. It is up to clients to do this with a storage solution of choice (i.e. NSUserDefaults, CoreData, Keychain).

## Installation

### CocoaPods

SwiftyStoreKit can be installed as a [CocoaPod](https://cocoapods.org/) and builds as a Swift framework. To install, include this in your Podfile.

```ruby
use_frameworks!

pod 'SwiftyStoreKit'
```
Once installed, just ```import SwiftyStoreKit``` in your classes and you're good to go.

### Carthage

To integrate SwiftyStoreKit into your Xcode project using [Carthage](https://github.com/Carthage/Carthage), specify it in your Cartfile:

```ogdl
github "bizz84/SwiftyStoreKit"
```

**NOTE**: Please ensure that you have the [latest](https://github.com/Carthage/Carthage/releases) Carthage installed.

## Swift 2.2 / 2.3 / 3.0

Swift 2.2 support is available on the [swift-2.2 branch](https://github.com/bizz84/SwiftyStoreKit/tree/swift-3.2) and compiles correctly as of Xcode 7.3.x and Xcode 8 GM.

Swift 2.3 support is available on the [swift-2.3 branch](https://github.com/bizz84/SwiftyStoreKit/tree/swift-2.3) and compiles correctly as of Xcode 8 GM.

Swift 3.0 support is currently available on the [master](https://github.com/bizz84/SwiftyStoreKit/tree/master) and compiles correctly as of Xcode 8 GM.

As for versioning:

* Swift 3.0 is tagged as version `0.5.x`
* Swift 2.3 is tagged as version `0.4.x`
* Swift 2.2 is tagged as version `0.3.x`

## Change Log

See the [Releases Page](https://github.com/bizz84/SwiftyStoreKit/releases)

## Sample Code
The project includes demo apps [for iOS](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreDemo/ViewController.swift) [and OSX](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreOSXDemo/ViewController.swift) showing how to use SwiftyStoreKit.
Note that the pre-registered in app purchases in the demo apps are for illustration purposes only and may not work as iTunes Connect may invalidate them.

#### Features
- Super easy to use block based API
- Support for consumable, non-consumable in-app purchases
- Support for free, auto renewable and non renewing subscriptions
- Receipt verification
- iOS, tvOS and OS X compatible
- enum-based error handling

## Known issues

#### Verify subscription

After a subscription has expired, the user can change the system date to the date prior expiration. This is a bug that needs to be fixed. [#68](https://github.com/bizz84/SwiftyStoreKit/issues/68)

#### Requests lifecycle

While SwiftyStoreKit tries handle concurrent purchase or restore purchases requests, it is not guaranteed that this will always work flawlessly.
This is in part because using a closure-based API does not map perfectly well with the lifecycle of payments in `SKPaymentQueue`.

In real applications the following could happen:

1. User starts a purchase
2. User kills the app
3. OS continues processing this, resulting in a failed or successful purchase
4. App is restarted (payment queue is not updated yet)
5. User starts another purchase (the old transaction may interfere with the new purchase)

To prevent situations like this from happening, a `completeTransactions()` method has been added in version 0.2.8. This should be called when the app starts as it can take care of clearing the payment queue and notifying the app of the transactions that have finished.

#### Multiple accounts

The user can background the hosting application and change the Apple ID used with the App Store, then foreground the app. This has been observed to cause problems with SwiftyStoreKit - other IAP implementations may suffer from this as well.

## Essential Reading
* [Apple - WWDC16, Session 702: Using Store Kit for In-app Purchases with Swift 3](https://developer.apple.com/videos/play/wwdc2016/702/)
* [Apple - TN2387: In-App Purchase Best Practices](https://developer.apple.com/library/content/technotes/tn2387/_index.html)
* [Apple - About Receipt Validation](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html)
* [Apple - Receipt Validation Programming Guide](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1)
* [Apple - Offering Subscriptions](https://developer.apple.com/app-store/subscriptions/)


## Implementation Details
In order to make a purchase, two operations are needed:

- Obtain the ```SKProduct``` corresponding to the productId that identifies the app purchase, via ```SKProductRequest```.

- Submit the payment for that product via ```SKPaymentQueue```.

The framework takes care of caching SKProducts so that future requests for the same ```SKProduct``` don't need to perform a new ```SKProductRequest```.

### Requesting products information

SwiftyStoreKit wraps the delegate-based ```SKProductRequest``` API with a block based class named ```InAppProductQueryRequest```, which returns a `RetrieveResults` value with information about the obtained products:

```swift
public struct RetrieveResults {
    public let retrievedProducts: Set<SKProduct>
    public let invalidProductIDs: Set<String>
    public let error: NSError?
}
```
This value is then surfaced back to the caller of the `retrieveProductsInfo()` method the completion closure so that the client can update accordingly.

### Purchasing a product / Restoring purchases
`InAppProductPurchaseRequest` is a wrapper class for `SKPaymentQueue` that can be used to purchase a product or restore purchases.

The class conforms to the `SKPaymentTransactionObserver` protocol in order to receive transactions notifications from the payment queue. The following outcomes are defined for a purchase/restore action:

```swift
enum TransactionResult {
    case purchased(productId: String)
    case restored(productId: String)
    case failed(error: NSError)
}
```
Depending on the operation, the completion closure for `InAppProductPurchaseRequest` is then mapped to either a `PurchaseResult` or a `RestoreResults` value and returned to the caller.

## Credits
Many thanks to [phimage](https://github.com/phimage) for adding OSX support and receipt verification.

## Apps using SwiftyStoreKit

It would be great to showcase apps using SwiftyStoreKit here. Pull requests welcome :)

* [MDacne](https://itunes.apple.com/app/id1044050208) - Acne analysis and treatment
* [Pixel Picker](https://itunes.apple.com/app/id930804327) - Image Color Picker
* [KType](https://itunes.apple.com/app/id1037000234) - Space shooter game
* [iPic](https://itunes.apple.com/app/id1101244278?ls=1&mt=12) - Automatically upload images and save Markdown links
* [iHosts](https://itunes.apple.com/app/id1102004240?ls=1&mt=12) - Perfect for editing /etc/hosts


## License

Copyright (c) 2015-2016 Andrea Bizzotto bizz84@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
