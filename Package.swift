// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParkCore",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "ParkCore", targets: ["ParkCore"])],
    targets: [
        .target(name: "ParkCore"),
        .executableTarget(name: "ParkFeedCheck", dependencies: ["ParkCore"]),
        .testTarget(name: "ParkCoreTests", dependencies: ["ParkCore"])
    ]
)
