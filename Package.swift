// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DialKitSwiftUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DialKitSwiftUI", targets: ["DialKitSwiftUI"])],
    targets: [
        .target(name: "DialKitSwiftUI", resources: [.copy("WebAssets")]),
        .testTarget(name: "DialKitSwiftUITests", dependencies: ["DialKitSwiftUI"])
    ]
)
