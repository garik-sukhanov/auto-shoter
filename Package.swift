// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoShoter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AutoShoter",
            path: "Sources/AutoShoter",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
