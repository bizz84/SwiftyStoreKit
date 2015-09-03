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
