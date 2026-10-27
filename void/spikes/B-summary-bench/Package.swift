// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "summary-bench",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../app/VoidCore"),
    ],
    targets: [
        .executableTarget(
            name: "summary-bench",
            dependencies: [.product(name: "VoidCore", package: "VoidCore")]
        ),
    ]
)
