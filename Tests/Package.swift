// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SelectionTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "SelectionTests",
            dependencies: [
                .product(name: "Selection", package: "Selection"),
                .product(name: "Position", package: "Position"),
                .product(name: "Readers", package: "Readers"),
            ]
        ),
    ]
)
