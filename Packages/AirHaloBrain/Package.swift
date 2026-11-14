// swift-tools-version: 6.0
import PackageDescription

// The gesture "brain": 21 hand points in, mouse/trackpad commands out.
// Foundation only, so the rules stay easy to port to other platforms.
let package = Package(
    name: "AirHaloBrain",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AirHaloBrain", targets: ["AirHaloBrain"]),
    ],
    targets: [
        .target(name: "AirHaloBrain"),
        .testTarget(
            name: "AirHaloBrainTests",
            dependencies: ["AirHaloBrain"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
