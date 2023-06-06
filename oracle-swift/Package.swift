// swift-tools-version: 5.8

import PackageDescription

/// Rename this name + Root Folder + Target Folder inside Source
let name: String = "oracle-swift"

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.76.3")),
    .package(url: "https://github.com/nerzh/everscale-client-swift.git", .upToNextMajor(from: "1.11.0")),
    .package(url: "https://github.com/bytehubio/BigInt.git", from: "5.2.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.2.2")),
    .package(url: "https://github.com/nerzh/SwiftFileUtils", .upToNextMinor(from: "1.3.0")),
    .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.0.0")),
]

var mainTarget: [Target.Dependency] = [
    .product(name: "adnl-swift", package: "adnl-swift"),
    .product(name: "Vapor", package: "vapor"),
    .product(name: "EverscaleClientSwift", package: "everscale-client-swift"),
    .product(name: "FileUtils", package: "SwiftFileUtils"),
]

var ctrlTarget: [Target.Dependency] = [
    .product(name: "EverscaleClientSwift", package: "everscale-client-swift"),
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
    .product(name: "FileUtils", package: "SwiftFileUtils"),
    .product(name: "adnl-swift", package: "adnl-swift"),
    .product(name: "Logging", package: "swift-log"),
]

#if os(Linux)
packageDependencies.append(.package(url: "https://github.com/nerzh/adnl-swift", branch: "master"))
#else
packageDependencies.append(.package(path: "/Users/nerzh/mydata/swift_projects/adnl-swift"))
#endif

let package = Package(
    name: name,
    platforms: [
        .macOS(.v12),
//        .iOS(.v13),
//        .tvOS(.v13),
//        .watchOS(.v6),
//        .macCatalyst(.v13)
    ],
    products: [
        .executable(name: name, targets: [name]),
        .executable(name: "oracle-ctrl", targets: ["oracle-ctrl"]),
    ],
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: name,
            dependencies: mainTarget,
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "oracle-ctrl",
            dependencies: ctrlTarget
        )
    ]
)
