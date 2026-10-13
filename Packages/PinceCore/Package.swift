// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PinceCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PinceCore", targets: ["PinceCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "PinceCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        // Harnais de tests : XCTest et Swift Testing ne sont pas livres avec
        // les Command Line Tools (voir docs/tests.md).
        .executableTarget(
            name: "pincecore-check",
            dependencies: ["PinceCore"]
        ),
    ]
)
