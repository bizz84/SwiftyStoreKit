# SwiftyStoreKit
SwiftyStoreKit is a lightweight In App Purchases framework for iOS 8.0+, written in Swift 2.0.
The framework provides a simple block based API with robust error handling on top of the existing StoreKit framework.

## Purchase a product

```swift
SwiftyStoreKit.sharedInstance.purchaseProduct("com.musevisions.SwiftyStoreKit.Purchase1") { result in
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

## Restore previous purchases

```swift
SwiftyStoreKit.sharedInstance.restorePurchases() { result in
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
```InAppProductPurchaseRequest``` is a wrapper class for ```SKPaymentQueue``` that can be use to purchase a product or restore purchases.

The class conforms to the ```SKPaymentTransactionObserver``` protocol in order to appropriately handle transactions in the payment queue. The following outcomes are defined for a purchase/restore action:

```swift
enum TransactionResult {
    case Purchased(productId: String)
    case Restored(productId: String)
    case NothingToRestore
    case Failed(error: NSError)
}
```

The ```SwiftyStoreKit``` class can then map the returned ```TransactionResult``` into either a success or failure case and pass this back to the client.
Note that along with the success and failure case, the result of a restore purchases operation also has a NothingToRestore case. This is so that the client can know that the operation returned, but no purchases were restored.








