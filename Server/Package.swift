// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BoberHouseServer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "App", targets: ["App"]),
        .executable(name: "Run", targets: ["Run"])
    ],
    dependencies: [
        // Vapor core
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.1.0"),
        
        // Add APNSwift
        .package(url: "https://github.com/swift-server-community/APNSwift.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "APNSwift", package: "APNSwift")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App")
            ]
        )
    ]
)
