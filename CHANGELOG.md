# Change Log

All notable changes to this project will be documented in this file.

## [0.11.0](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.11.0) Add `fetchReceipt` method + update `verifyReceipt` and `ReceiptValidator` protocol

* Add `fetchReceipt` method. Update `verifyReceipt` to use it ([#278](https://github.com/bizz84/SwiftyStoreKit/pull/278), related issues: [#272](https://github.com/bizz84/SwiftyStoreKit/issues/272), [#223](https://github.com/bizz84/SwiftyStoreKit/issues/223)).
* Update `fetchReceipt` and `ReceiptValidator` to use receipt as `Data` rather than `String`. This is consistent with `localReceiptData` ([#284](https://github.com/bizz84/SwiftyStoreKit/pull/284), see [#272](https://github.com/bizz84/SwiftyStoreKit/issues/272)).
* Remove `password` from `ReceiptValidator` protocol as this is specific to `AppleReceiptValidator` ([#281](https://github.com/bizz84/SwiftyStoreKit/pull/281/), see [#263](https://github.com/bizz84/SwiftyStoreKit/issues/263)). **Note**: This is an API breaking change.


## [0.10.8](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.8) Update to swiftlint 0.22.0

* Update to swiftlint 0.22.0 ([#270](https://github.com/bizz84/SwiftyStoreKit/pull/270), fix for [#273](https://github.com/bizz84/SwiftyStoreKit/issues/273))

## [0.10.7](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.7) Fix for concurrent `retrieveProductsInfo` calls

* `ProductsInfoController`: Keep track of multiple completion blocks for the same request ([#259](https://github.com/bizz84/SwiftyStoreKit/pull/259), fix for [#250](https://github.com/bizz84/SwiftyStoreKit/issues/250))

## [0.10.6](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.6) Add support for shouldAddStorePayment

* Add support for the new `SKPaymentTransactionObserver.shouldAddStorePayment` method in iOS 11 ([#257](https://github.com/bizz84/SwiftyStoreKit/pull/257), related issue: [#240](https://github.com/bizz84/SwiftyStoreKit/issues/240))
* Update swiftlint to version 0.21.0 ([#258](https://github.com/bizz84/SwiftyStoreKit/pull/258))

## [0.10.5](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.5) Filter out transactions in purchasing state
* Filter out all transactions with `state == .purchasing` early in purchase flows (related to [#169](https://github.com/bizz84/SwiftyStoreKit/issues/169), [#188](https://github.com/bizz84/SwiftyStoreKit/pull/188), [#179](https://github.com/bizz84/SwiftyStoreKit/issues/179))
* Sample app: print localized description when a purchase fails with `.unknown` error

## [0.10.4](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.4) Documentation and updates for Xcode 9

* Update to Xcode 9 recommended project settings ([#247](https://github.com/bizz84/SwiftyStoreKit/pull/247))
* Update build script iOS version to 10.3.1 ([#245](https://github.com/bizz84/SwiftyStoreKit/pull/245))
* Update notes about Xcode 9, Swift 4 support to README

## [0.10.3](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.3) Add `forceRefresh` option to `verifyReceipt`

* Add `forceRefresh` option to `verifyReceipt` ([#224](https://github.com/bizz84/SwiftyStoreKit/pull/224), fix for [#223](https://github.com/bizz84/SwiftyStoreKit/issues/223))

## [0.10.2](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.2) Remove SKProduct caching

* Remove SKProduct caching ([#222](https://github.com/bizz84/SwiftyStoreKit/pull/222), related issue: [#212](https://github.com/bizz84/SwiftyStoreKit/issues/212))
* Adds new purchase product method based on SKProduct

## [0.10.1](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.1) Danger, xcpretty integration

* Adds Danger for better Pull Request etiquette ([#215](https://github.com/bizz84/SwiftyStoreKit/pull/215)).
* Adds xcpretty to improve build logs ([#217](https://github.com/bizz84/SwiftyStoreKit/pull/217))
* Update SwiftLint to 0.18.1 ([#218](https://github.com/bizz84/SwiftyStoreKit/pull/218))

## [0.10.0](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.10.0) `verifyReceipt` now automatically refreshes the receipt if needed

#### API removed: `refreshReceipt`

This release simplifies the receipt verification flows by removing the `refreshReceipt` method from the public API.

Now clients only need to call `verifyReceipt` and the receipt is refreshed internally if needed.

Addressed in [#213](https://github.com/bizz84/SwiftyStoreKit/pull/213), related issue: [#42](https://github.com/bizz84/SwiftyStoreKit/issues/42).

The documentation in the README and various methods has also been considerably improved.

## [0.9.3](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.9.3) Dispatch callbacks on main thread on macOS

This is a minor release to ensure callbacks are dispatched on the main thread on macOS.

PR [#214](https://github.com/bizz84/SwiftyStoreKit/pull/214), fix for [#211](https://github.com/bizz84/SwiftyStoreKit/issues/211).

## [0.9.2](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.9.2) Fix for failing receipt verification due to missing optional field

This is a critical fix for [#208](https://github.com/bizz84/SwiftyStoreKit/issues/208).

If you're using release 0.9.0, please update.

## [0.9.1](https://github.com/bizz84/SwiftyStoreKit/releases/tag/0.9.1) Expose SKProduct in PurchaseDetails type returned by PurchaseResult

This is a minor release which includes a fix for [#185](https://github.com/bizz84/SwiftyStoreKit/issues/185) (addressed in [#206](https://github.com/bizz84/SwiftyStoreKit/pull/206)). Summary:

When a purchase succeeds, it is desirable to get access to the purchased `SKProduct` in the completion block, so that it's possible to query the `price` and other properties.

With this change, this is now possible:

```swift
SwiftyStoreKit.purchaseProduct("productId", atomically: true) { result in
    if case .success(let purchase) = result {
        // Deliver content from server, then:
        if purchase.needsFinishTransaction {
            SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
        print("Purchased product with price: \(purchase.product.price)")
    }
}
```

## [0.9.0](https://github.com/bizz84/SwiftyStoreKit/releases/edit/0.9.0) Verify Subscription improvements + added quantity and originalTransaction to Payment

**NOTE** This release introduces some API breaking changes (see [#202](https://github.com/bizz84/SwiftyStoreKit/pull/202)). Change-set:

### [#198](https://github.com/bizz84/SwiftyStoreKit/pull/198): Subscription verification unit tests

### [#199](https://github.com/bizz84/SwiftyStoreKit/pull/199) (fixes [#192](https://github.com/bizz84/SwiftyStoreKit/issues/192), [#190](https://github.com/bizz84/SwiftyStoreKit/issues/190) and [#65](https://github.com/bizz84/SwiftyStoreKit/issues/65)): Add `ReceiptItem` to `VerifyPurchaseResult`, `VerifySubscriptionResult`

This change introduces a new strong-typed `ReceiptItem` struct:

```swift
public struct ReceiptItem {
    // The product identifier of the item that was purchased. This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
    public let productId: String
    // The number of items purchased. This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
    public let quantity: Int
    // The transaction identifier of the item that was purchased. This value corresponds to the transaction’s transactionIdentifier property.
    public let transactionId: String
    // For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier. This value corresponds to the original transaction’s transactionIdentifier property. All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
    public let originalTransactionId: String
    // The date and time that the item was purchased. This value corresponds to the transaction’s transactionDate property.
    public let purchaseDate: Date
    // For a transaction that restores a previous transaction, the date of the original transaction. This value corresponds to the original transaction’s transactionDate property. In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
    public let originalPurchaseDate: Date
    // The primary key for identifying subscription purchases.
    public let webOrderLineItemId: String
    // The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT. This key is only present for auto-renewable subscription receipts.
    public let subscriptionExpirationDate: Date?
    // For a transaction that was canceled by Apple customer support, the time and date of the cancellation. Treat a canceled receipt the same as if no purchase had ever been made.
    public let cancellationDate: Date?

    public let isTrialPeriod: Bool
}
```

This is parsed from the receipt and returned as part of the `verifySubscription` and `verifyPurchase` methods:

```swift
// Result for Consumable and NonConsumable
public enum VerifyPurchaseResult {
    case purchased(item: ReceiptItem)
    case notPurchased
}

// Verify subscription result
public enum VerifySubscriptionResult {
    case purchased(expiryDate: Date, items: [ReceiptItem])
    case expired(expiryDate: Date, items: [ReceiptItem])
    case notPurchased
}
```

Note that when one or more subscriptions are found for a given product id, they are returned as a `ReceiptItem` array ordered by `expiryDate`, with the first one being the newest.

This is useful to get all the valid date ranges for a given subscription.

### [#202](https://github.com/bizz84/SwiftyStoreKit/pull/202) (fix for [#200](https://github.com/bizz84/SwiftyStoreKit/issues/200)): It's now possible to specify the quantity when making a purchase. Quantity is also accessible in the callback.

#### This is an API breaking change. `Product` has been renamed to `Purchase`:

```swift
public struct Purchase {
    public let productId: String
    public let quantity: Int
    public let transaction: PaymentTransaction
    public let needsFinishTransaction: Bool
}
```

#### `PurchaseResult`

```swift
public enum PurchaseResult {
    //case success(product: Product) // old
    case success(purchase: Purchase) // new
    case error(error: SKError)
}
```

#### `RestoreResults`

```swift
public struct RestoreResults {
    //public let restoredProducts: [Product] // old
    //public let restoreFailedProducts: [(SKError, String?)] // old
    public let restoredPurchases: [Purchase] // new
    public let restoreFailedPurchases: [(SKError, String?)] // new
}
```

### [#203](https://github.com/bizz84/SwiftyStoreKit/pull/203) (fix for [#193](https://github.com/bizz84/SwiftyStoreKit/issues/193)): Add `originalTransaction` from `SKPaymentTransaction.original` to `Payment` type



## TODO: Older releases
