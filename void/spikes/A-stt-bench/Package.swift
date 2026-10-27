// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "stt-bench",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "stt-bench",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")]
        ),
    ]
)
