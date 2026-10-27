// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoidCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "VoidCore", targets: ["VoidCore"]),
    ],
    targets: [
        .target(name: "VoidCore"),
        .testTarget(name: "VoidCoreTests", dependencies: ["VoidCore"]),
    ]
)
