// swift-tools-version: 5.8

import PackageDescription

/// Rename this name + Root Folder + Target Folder inside Source
let name: String = "oracle-swift"

var packageDependencies: [Package.Dependency] = [
//    .package(path: "/Users/nerzh/mydata/swift_projects/adnl-swift")
//    .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.45.0")),
//    .package(url: "https://github.com/nerzh/VaporBridges.git", branch: "master"),
//    .package(url: "https://github.com/nerzh/PostgresBridge.git", branch: "master"),
//    .package(url: "https://github.com/nerzh/Bridges.git", branch: "master"),
//    .package(url: "https://github.com/nerzh/swift-regular-expression.git", .upToNextMajor(from: "0.2.3")),
//    .package(url: "https://github.com/nerzh/SwiftFileUtils", .upToNextMinor(from: "1.3.0")),
//    .package(url: "https://github.com/orlandos-nl/IkigaJSON.git", from: "2.0.0"),
//    .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.53.0")),
    .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.76.3")),
]

var mainTarget: [Target.Dependency] = [
    .product(name: "adnl-swift", package: "adnl-swift"),
//    .product(name: "NIOCore", package: "swift-nio"),
//    .product(name: "NIO", package: "swift-nio"),
//    .product(name: "NIOPosix", package: "swift-nio"),
//    .product(name: "NIOTLS", package: "swift-nio"),
    .product(name: "Vapor", package: "vapor"),
]

#if os(Linux)
packageDependencies.append(.package(url: "https://github.com/nerzh/adnl-swift", branch: "master"))
#else
packageDependencies.append(.package(path: "/Users/nerzh/mydata/swift_projects/adnl-swift"))
#endif

let package = Package(
    name: name,
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: name, targets: [name])
    ],
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: name,
            dependencies: mainTarget,
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]),
    ]
)
