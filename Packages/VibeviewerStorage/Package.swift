// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VibeviewerStorage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VibeviewerStorage", targets: ["VibeviewerStorage"])
    ],
    dependencies: [
        .package(path: "../VibeviewerModel"),
        .package(path: "../VibeviewerAPI"),
        .package(path: "../VibeviewerCore")
    ],
    targets: [
        .target(
            name: "VibeviewerStorage",
            dependencies: [
                .product(name: "VibeviewerModel", package: "VibeviewerModel"),
                .product(name: "VibeviewerAPI", package: "VibeviewerAPI"),
                .product(name: "VibeviewerCore", package: "VibeviewerCore")
            ]
        ),
        .testTarget(
            name: "VibeviewerStorageTests",
            dependencies: ["VibeviewerStorage"]
        )
    ]
)


