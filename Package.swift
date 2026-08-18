// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-only

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
