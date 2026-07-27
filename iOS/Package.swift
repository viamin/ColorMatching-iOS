// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ColorMatchingLPS",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ColorMatchingLPSAppCore", targets: ["ColorMatchingLPSAppCore"]),
        .library(name: "MeasurementCore", targets: ["MeasurementCore"]),
        .executable(name: "ColorMatchingLPS", targets: ["ColorMatchingLPSApp"])
    ],
    targets: [
        .target(name: "MeasurementCore"),
        .target(
            name: "ColorMatchingLPSAppCore",
            dependencies: ["MeasurementCore"]
        ),
        .executableTarget(
            name: "ColorMatchingLPSApp",
            dependencies: ["ColorMatchingLPSAppCore", "MeasurementCore"]
        ),
        .testTarget(
            name: "MeasurementCoreTests",
            dependencies: ["MeasurementCore"]
        ),
        .testTarget(
            name: "ColorMatchingLPSAppTests",
            dependencies: ["ColorMatchingLPSAppCore"]
        )
    ]
)
