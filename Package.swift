// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MMNetwork",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MMNetwork", targets: ["MMNetwork"])
    ],
    dependencies: [
        .package(url: "https://github.com/iAmMccc/SmartCodable", .upToNextMajor(from: "5.0.2")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.10.2"))
    ],
    targets: [
        .target(name: "MMNetwork", dependencies: [
            .product(name: "SmartCodable", package: "SmartCodable"),
            .product(name: "Alamofire", package: "Alamofire")
        ]),
        .testTarget( name: "MMNetworkTests", dependencies: ["MMNetwork"])
    ]
)
