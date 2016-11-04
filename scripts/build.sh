#!/bin/bash

xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_iOS
xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_macOS
xcodebuild -project SwiftyStoreKit.xcodeproj -target SwiftyStoreKit_tvOS
