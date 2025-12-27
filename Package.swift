// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-ast-dump",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "601.0.1")
    ],
    targets: [
        .executableTarget(
            name: "swift-ast-dump",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources"
        )
    ]
)
