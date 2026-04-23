// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Selection",
    products: [
        .library(
            name: "Selection",
            targets: ["Selection"]
        ),
        .library(
            name: "SelectionParsing",
            targets: ["SelectionParsing"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Selection",
            dependencies: [
                .product(name: "Position", package: "Position"),
                .product(name: "Path", package: "Path"),
                .product(name: "Readers", package: "Readers"),
            ],
        ),
        .target(
            name: "SelectionParsing",
            dependencies: [
                "Selection",
                .product(name: "Position", package: "Position"),
                .product(name: "Path", package: "Path"),
                .product(name: "PathParsing", package: "Path"),
            ],
        ),
        .testTarget(
            name: "SelectionTests",
            dependencies: ["Selection"]
        ),
    ]
)
