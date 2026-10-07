// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OnDeviceTranslationEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OnDeviceTranslationEngine",
            targets: ["OnDeviceTranslationEngine"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jkrukowski/swift-sentencepiece.git", from: "0.0.3")
    ],
    targets: [
        .target(
            name: "OnDeviceTranslationEngine",
            dependencies: [
                .product(name: "SentencepieceTokenizer", package: "swift-sentencepiece")
            ]
        ),
        .testTarget(
            name: "OnDeviceTranslationEngineTests",
            dependencies: ["OnDeviceTranslationEngine"]
        )
    ]
)
