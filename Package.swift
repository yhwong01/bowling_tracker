// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BowlingTrackingCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BowlingTrackingCore",
            targets: ["BowlingTrackingCore"]
        ),
        .executable(
            name: "BowlingVideoAnalyzerCLI",
            targets: ["BowlingVideoAnalyzerCLI"]
        )
    ],
    targets: [
        .target(
            name: "BowlingTrackingCore"
        ),
        .executableTarget(
            name: "BowlingVideoAnalyzerCLI",
            dependencies: ["BowlingTrackingCore"]
        ),
        .testTarget(
            name: "BowlingTrackingCoreTests",
            dependencies: ["BowlingTrackingCore"]
        )
    ]
)
