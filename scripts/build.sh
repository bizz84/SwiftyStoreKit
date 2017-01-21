#!/bin/bash

xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_iOS
xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_macOS
xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_tvOS

xcodebuild test -project SwiftyStoreKit.xcodeproj -scheme SwiftyStoreKitTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 6,OS=9.3'
