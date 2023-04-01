// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SwiftyStoreKit",
    platforms: [.iOS("11.0"), .macOS("10.13"), .tvOS("11.0"), .watchOS("6.2")],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftyStoreKit",
            targets: ["SwiftyStoreKit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftyStoreKit",
            dependencies: []),
        .testTarget(
            name: "SwiftyStoreKitTests",
            dependencies: ["SwiftyStoreKit"])
    ]
)
