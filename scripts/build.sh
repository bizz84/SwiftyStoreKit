#!/bin/bash

xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_iOS | tee xcodebuild.log | xcpretty
xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_macOS | tee xcodebuild.log | xcpretty
xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_tvOS | tee xcodebuild.log | xcpretty

xcodebuild test -project SwiftyStoreKit.xcodeproj -scheme SwiftyStoreKitTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 6,OS=10.3' | tee xcodebuild.log | xcpretty
