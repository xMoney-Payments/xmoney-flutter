// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Flutter looks for this manifest at ios/xmoney_ios/Package.swift.
// The pin matches xmoney_ios.podspec so SwiftPM cannot float past CocoaPods.

let package = Package(
    name: "xmoney_ios",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "xmoney-ios", targets: ["xmoney_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/xMoney-Payments/xmoney-ios.git", exact: "1.0.1")
    ],
    targets: [
        .target(
            name: "xmoney_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "XMoneyPaymentSheet", package: "xmoney-ios")
            ]
        )
    ]
)
