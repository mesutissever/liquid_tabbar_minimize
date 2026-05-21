// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "liquid_tabbar_minimize",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "liquid-tabbar-minimize", targets: ["liquid_tabbar_minimize"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "liquid_tabbar_minimize",
            dependencies: [],
            resources: []
        )
    ]
)
