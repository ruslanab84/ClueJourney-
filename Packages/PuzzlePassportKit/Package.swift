// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PuzzlePassportKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PPDomain", targets: ["PPDomain"]),
        .library(name: "PPGameEngine", targets: ["PPGameEngine"]),
        .library(name: "PPApplication", targets: ["PPApplication"]),
        .library(name: "PPData", targets: ["PPData"]),
        .library(name: "PPDesignSystem", targets: ["PPDesignSystem"]),
        .library(name: "PPFeatures", targets: ["PPFeatures"]),
        .executable(name: "ContentValidator", targets: ["ContentValidator"]),
    ],
    targets: [
        .target(name: "PPDomain"),
        .target(name: "PPGameEngine", dependencies: ["PPDomain"]),
        .target(name: "PPApplication", dependencies: ["PPDomain", "PPGameEngine"]),
        .target(name: "PPData", dependencies: ["PPDomain", "PPApplication"]),
        .target(name: "PPDesignSystem"),
        .target(
            name: "PPFeatures",
            dependencies: ["PPDomain", "PPApplication", "PPDesignSystem"]
        ),
        .executableTarget(
            name: "ContentValidator",
            dependencies: ["PPDomain", "PPGameEngine", "PPData"]
        ),
        .testTarget(name: "PPDomainTests", dependencies: ["PPDomain"]),
        .testTarget(
            name: "PPGameEngineTests",
            dependencies: ["PPDomain", "PPGameEngine"]
        ),
        .testTarget(
            name: "PPApplicationTests",
            dependencies: ["PPDomain", "PPApplication"]
        ),
        .testTarget(
            name: "PPDataTests",
            dependencies: ["PPDomain", "PPApplication", "PPData"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
