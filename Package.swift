// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShapeBar",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git",
                 .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        .executableTarget(
            name: "ShapeBar",
            dependencies: [
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk")
            ],
            path: "Sources/ShapeBar"
        ),
        .testTarget(
            name: "ShapeBarTests",
            dependencies: ["ShapeBar"]
        )
    ]
)
