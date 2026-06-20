// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CueShot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CueShot", targets: ["CueShot"])
    ],
    targets: [
        .executableTarget(
            name: "CueShot",
            path: "Sources/CueShot"
        ),
        .testTarget(
            name: "CueShotTests",
            dependencies: ["CueShot"],
            path: "Tests/CueShotTests"
        )
    ]
)
