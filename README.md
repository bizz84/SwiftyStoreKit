# SwiftyStoreKit
SwiftyStoreKit is a lightweight In App Purchases framework for iOS 8.0+, written in Swift 2.0.

### Preview

<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview.png" width="375">
<img src="https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview2.png" width="375">

### Retrieve product info
```swift
SwiftyStoreKit.retrieveProductInfo("com.musevisions.SwiftyStoreKit.Purchase1") { result in
    switch result {
    case .Success(let product):
        let priceString = NSNumberFormatter.localizedStringFromNumber(product.price, numberStyle: .CurrencyStyle)
        print("Product: \(product.localizedDescription), price: \(priceString)")
        break
    case .Error(let error):
        print("Error: \(error)")
        break
    }
}
```
### Purchase a product

```swift
SwiftyStoreKit.purchaseProduct("com.musevisions.SwiftyStoreKit.Purchase1") { result in
    switch result {
    case .Success(let productId):
        print("Purchase Success: \(productId)")
        break
    case .Error(let error):
        print("Purchase Failed: \(error)")
        break
    }
}
```

### Restore previous purchases

```swift
SwiftyStoreKit.restorePurchases() { result in
    switch result {
    case .Success(let productId):
        print("Restore Success: \(productId)")
        break
    case .NothingToRestore:
        print("Nothing to Restore")
        break
    case .Error(let error):
        print("Restore Failed: \(error)")
        break
    }
}
```

**NOTE**:
The framework provides a simple block based API with robust error handling on top of the existing StoreKit framework. It does **NOT** persist in app purchases data locally. It is up to clients to do this with a storage solution of choice (i.e. NSUserDefaults, CoreData, Keychain).

## Installation
SwiftyStoreKit can be installed as a Cocoapod and builds as a Swift framework. To install, include this in your Podfile.
```
use_frameworks!

pod 'SwiftyStoreKit'
```
Once installed, just ```import SwiftyStoreKit``` in your classes and you're good to go.

## Sample Code
The project includes a demo app showing [how to use](https://github.com/bizz84/SwiftyStoreKit/blob/master/SwiftyStoreDemo/ViewController.swift) SwiftyStoreKit.
Note that the pre-registered in app purchases in the demo app are for illustration purposes only and may not work as iTunes Connect may invalidate them.

#### Features
- Super easy to use block based API
- enum-based error handling
- Support for non-consumable in app purchases

#### Missing Features
- Receipt verification
- Ask To Buy

#### Untested Features
- Consumable in app purchases
- Free subscriptions for Newsstand

## Implementation Details
In order to make a purchase, two operations are needed:
- Obtain the ```SKProduct``` corresponding to the productId that identifies the app purchase, via ```SKProductRequest```.
- Submit the payment for that product via ```SKPaymentQueue```.

The framework takes care of caching SKProducts so that future requests for the same ```SKProduct``` don't need to perform a new ```SKProductRequest```.

### Requesting a product
SwiftyStoreKit wraps the delegate-based ```SKProductRequest``` API with a block based class named ```InAppProductQueryRequest```, which returns either a success case with a list of valid products, or an error comprising the following cases:

```swift
public enum ResponseError : ErrorType {
    case InvalidProducts(invalidProductIdentifiers: [String])
    case NoProducts
    case RequestFailed(error: NSError)
}
```

If ```InAppProductQueryRequest``` returns an error, this is surfaced directly to the completion block of ```SwiftyStoreKit.purchaseProduct```, so that the client can examine it and react accordingly.
In case of success, the product is cached and the purchase can take place via the ```InAppProductPurchaseRequest``` class.

### Purchasing a product / Restoring purchases
```InAppProductPurchaseRequest``` is a wrapper class for ```SKPaymentQueue``` that can be used to purchase a product or restore purchases.

The class conforms to the ```SKPaymentTransactionObserver``` protocol in order to receive transactions notifications from the payment queue. The following outcomes are defined for a purchase/restore action:

```swift
enum TransactionResult {
    case Purchased(productId: String)
    case Restored(productId: String)
    case NothingToRestore
    case Failed(error: NSError)
}
```

The ```SwiftyStoreKit``` class can then map the returned ```TransactionResult``` into either a success or failure case and pass this back to the client.
Note that along with the success and failure case, the result of a restore purchases operation also has a ```NothingToRestore``` case. This is so that the client can know that the operation returned, but no purchases were restored.

## License

Copyright (c) 2015 Andrea Bizzotto bizz84@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.






