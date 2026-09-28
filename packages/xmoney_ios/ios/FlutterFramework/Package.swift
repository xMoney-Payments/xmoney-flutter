// swift-tools-version: 5.9
// Vend the Flutter engine so `import Flutter` resolves when this package is
// opened directly. Flutter's generated sibling package is only an empty
// placeholder. The xcframework symlink is created by link-flutter-framework.sh
// (SwiftPM evaluates this manifest in a sandbox and cannot create it).

import PackageDescription

let package = Package(
    name: "FlutterFramework",
    products: [
        .library(name: "FlutterFramework", targets: ["Flutter"])
    ],
    targets: [
        .binaryTarget(name: "Flutter", path: "Flutter.xcframework")
    ]
)
