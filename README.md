# SwiftyStoreKit
SwiftyStoreKit is a lightweight In App Purchases framework for iOS 8.0+ and OSX 9.0+, written in Swift.

[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat
            )](http://mit-license.org)
[![Platform](http://img.shields.io/badge/platform-ios%20%7C%20osx-lightgrey.svg?style=flat
             )](https://developer.apple.com/resources/)
[![Language](http://img.shields.io/badge/language-swift-orange.svg?style=flat
             )](https://developer.apple.com/swift)
[![Issues](https://img.shields.io/github/issues/bizz84/SwiftyStoreKit.svg?style=flat
           )](https://github.com/bizz84/SwiftyStoreKit/issues)
[![Cocoapod](http://img.shields.io/cocoapods/v/SwiftyStoreKit.svg?style=flat)](http://cocoadocs.org/docsets/SwiftyStoreKit/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)


### Preview

<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview.png" width="320">
<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview2.png" width="320">

### Retrieve products info
```swift
SwiftyStoreKit.retrieveProductsInfo(["com.musevisions.SwiftyStoreKit.Purchase1"]) { result in
    if let product = result.retrievedProducts.first {
        let priceString = NSNumberFormatter.localizedStringFromNumber(product.price ?? 0, numberStyle: .CurrencyStyle)
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
    case .Success(let productId):
        print("Purchase Success: \(productId)")
    case .Error(let error):
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

### Verify Receipts

```swift
SwiftyStoreKit.verifyReceipt() { result in
    if case .Error(let error) = result {
        if case .NoReceiptData = error {
            self.refreshReceipt()
        }
    }
}

func refreshReceipt() {
    SwiftyStoreKit.refreshReceipt { result in
        switch result {
        case .Success:
            print("Receipt refresh success")
        case .Error(let error):
            print("Receipt refresh failed: \(error)")
        }
    }
}
```


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


## Sample Code
The project includes demo apps [for iOS](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreDemo/ViewController.swift) [and OSX](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreOSXDemo/ViewController.swift) showing how to use SwiftyStoreKit.
Note that the pre-registered in app purchases in the demo apps are for illustration purposes only and may not work as iTunes Connect may invalidate them.

#### Features
- Super easy to use block based API
- enum-based error handling
- Support for non-consumable in app purchases
- Receipt verification

#### Missing Features
- Ask To Buy

#### Untested Features
- Consumable in app purchases
- Free subscriptions for Newsstand

## Changelog

### Version 0.2.6

* Retrieve multiple products info at once. Introduces the new `retrieveProductsInfo()` API call, which takes a set of product IDs and returns a struct with information about the corresponding SKProducts. [Related issue #21](https://github.com/bizz84/SwiftyStoreKit/issues/21)

### Version 0.2.5

* The `restorePurchases()` completion closure has been changed to return all restored purchases in one call. [Related issue #18](https://github.com/bizz84/SwiftyStoreKit/issues/18)

### Version 0.2.4

* Carthage compatible
* Fixed Swift 2.2 warnings

### Previous versions

* Receipt verification
* OS X support

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
    case Purchased(productId: String)
    case Restored(productId: String)
    case Failed(error: NSError)
}
```
Depending on the operation, the completion closure for `InAppProductPurchaseRequest` is then mapped to either a `PurchaseResult` or a `RestoreResults` value and returned to the caller.

## Credits
Many thanks to [phimage](https://github.com/phimage) for adding OSX support and receipt verification.

## Apps using SwiftyStoreKit

It would be great to showcase apps using SwiftyStoreKit here. Pull requests welcome :)

* [Pixel Picker](https://itunes.apple.com/app/id930804327) - Image Color Picker
* [KType](https://itunes.apple.com/app/id1037000234) - Space shooter game


## License

Copyright (c) 2015-2016 Andrea Bizzotto bizz84@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.






