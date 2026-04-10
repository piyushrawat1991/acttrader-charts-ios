// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ActtraderCharts",
    platforms: [
        .iOS(.v14),
        .macOS(.v12), // enables `swift test` on macOS for pure-Swift files (UIKit code is guarded)
    ],
    products: [
        .library(
            name: "ActtraderCharts",
            targets: ["ActtraderCharts"]
        ),
    ],
    targets: [
        .target(
            name: "ActtraderCharts",
            resources: [
                .copy("Resources/chart.html"),
            ]
        ),
        .testTarget(
            name: "ActtraderChartsTests",
            dependencies: ["ActtraderCharts"]
        ),
    ]
)
