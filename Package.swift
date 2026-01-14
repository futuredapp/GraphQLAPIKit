// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphQLAPIKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GraphQLAPIKit",
            targets: [
                "GraphQLAPIKit"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apollographql/apollo-ios.git",
            exact: "2.0.4"
        )
    ],
    targets: [
        .target(
            name: "GraphQLAPIKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
            ]
        ),
        .testTarget(
            name: "GraphQLAPIKitTests",
            dependencies: [
                "GraphQLAPIKit"
            ]
        )
    ]
)
