// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphQLAPIKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v11)
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
            exact: "1.17.0" // Do not forget to download related to this version Apollo CLI and include it with package
        )
    ],
    targets: [
        .target(
            name: "GraphQLAPIKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
            ]
        )
    ]
)
