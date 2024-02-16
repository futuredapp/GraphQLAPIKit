// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphQLAPIKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_14)
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
            from: "1.9.0"
        )
    ],
    targets: [
        .target(
            name: "GraphQLAPIKit",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
            ],
            exclude: [
                // "Networking/CloudAPIAdapter/CloudGraphQL/PasswordManagementMutations.graphql",
                // "Networking/CloudAPIAdapter/CloudGraphQL/PasswordManagementQueries.graphql",
                // "Networking/CloudAPIAdapter/CloudGraphQL/schema.json",
                // "Networking/CloudAPIAdapter/CloudGraphQL/apollo-codegen-config.json"
            ]
        )
    ]
)
