// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "hummingbird-macrorouting",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17)],
    products: [
        .library(name: "HummingbirdMacroRouting", targets: ["HummingbirdMacroRouting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        .target(
            name: "HummingbirdMacroRouting",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .byName(name: "RoutingMacros")
            ],
            path: "Sources/HummingbirdMacroRouting"
        ),
        .macro(
            name: "RoutingMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
            path: "Sources/RoutingMacros"
        ),
        .testTarget(
            name: "HummingbirdMacroRoutingTests",
            dependencies: [
                .byName(name: "HummingbirdMacroRouting"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ],
            path: "Tests"
        )
    ]
)
