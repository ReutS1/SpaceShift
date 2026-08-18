// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpaceShift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SpaceShift", targets: ["SpaceShift"])
    ],
    targets: [
        .executableTarget(
            name: "SpaceShift",
            path: "Sources/SpaceShift"
        )
    ]
)
