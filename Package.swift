// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ArmorD",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "ArmorD",
            targets: ["ArmorD"]
        )
    ],
    targets: [
        .target(
            name: "ArmorD",
            dependencies: []
        ),
        .testTarget(
            name: "ArmorDTests",
            dependencies: ["ArmorD"]
        )
    ]
)
