// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StackLight",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StackLightCore", targets: ["StackLightCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git",
                 .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/groue/GRDB.swift.git",
                 .upToNextMajor(from: "6.29.0"))
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
        .testTarget(
            name: "StackLightTests",
            dependencies: ["StackLight", "StackLightCore"]
        )
    ]
)
