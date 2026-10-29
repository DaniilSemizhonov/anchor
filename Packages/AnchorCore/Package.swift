// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnchorCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnchorCore", targets: ["AnchorCore"]),
    ],
    targets: [
        .target(name: "AnchorCore"),
        .testTarget(name: "AnchorCoreTests", dependencies: ["AnchorCore"]),
    ]
)
