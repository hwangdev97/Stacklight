// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StackLight",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "StackLightCore", targets: ["StackLightCore"]),
        .executable(name: "stacklightcli", targets: ["stacklightcli"])
    ],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git",
                 .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/groue/GRDB.swift.git",
                 .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git",
                 .upToNextMajor(from: "1.5.0"))
    ],
    targets: [
        .target(
            name: "StackLightCore",
            dependencies: [
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/StackLightCore"
        ),
        .executableTarget(
            name: "StackLight",
            dependencies: ["StackLightCore"],
            path: "Sources/StackLight"
        ),
        .executableTarget(
            name: "stacklightcli",
            dependencies: [
                "StackLightCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/stacklightcli",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "StackLightTests",
            dependencies: ["StackLight", "StackLightCore"]
        ),
        .testTarget(
            name: "StackLightCoreTests",
            dependencies: ["StackLightCore"],
            path: "Tests/StackLightCoreTests"
        )
    ]
)
