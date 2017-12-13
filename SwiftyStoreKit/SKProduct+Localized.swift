//
// SKProduct+LocalizedPrice.swift
// SwiftyStoreKit
//
// Created by Andrea Bizzotto on 19/10/2016.
// Copyright (c) 2015 Andrea Bizzotto (bizz84@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import StoreKit

public extension SKProduct {

    public var localizedPrice: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = self.priceLocale
        numberFormatter.numberStyle = .currency
        return numberFormatter.string(from: self.price)
    }
    
    @available(iOS 11.2, OSX 10.13.2, *)
    public var localizedIntroductoryPrice: String? {
        guard let price = introductoryPrice?.price, let locale = introductoryPrice?.priceLocale else { return nil }
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .currency
        return numberFormatter.string(from: price)
    }
    
    @available(iOS 11.2, OSX 10.13.2, *)
    public var localizedSubscriptionPeriod: String? {
        guard let subscriptionPeriod = subscriptionPeriod else { return nil }
        return localizedPeriod(period: subscriptionPeriod)
    }
    
    @available(iOS 11.2, OSX 10.13.2, *)
    public var localizedIntroductoryPeriod: String? {
        guard let introductoryPeriod = introductoryPrice?.subscriptionPeriod else { return nil }
        return localizedPeriod(period: introductoryPeriod)
    }

    @available(iOS 11.2, OSX 10.13.2, *)
    private func localizedPeriod(period: SKProductSubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return String(format: NSLocalizedString("localized subscription period day", comment: "localized subscription period day"), arguments: [period.numberOfUnits])
        case .week: return String(format: NSLocalizedString("localized subscription period week", comment: "localized subscription period week"), arguments: [period.numberOfUnits])
        case .month: return String(format: NSLocalizedString("localized subscription period month", comment: "localized subscription period month"), arguments: [period.numberOfUnits])
        case .year: return String(format: NSLocalizedString("localized subscription period year", comment: "localized subscription period year"), arguments: [period.numberOfUnits])
        }
    }
    
}
