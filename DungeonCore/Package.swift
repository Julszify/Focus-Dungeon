// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DungeonCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DungeonCore", targets: ["DungeonCore"]),
    ],
    targets: [
        .target(name: "DungeonCore"),
        .executableTarget(name: "dungeon-demo", dependencies: ["DungeonCore"]),
        .testTarget(name: "DungeonCoreTests", dependencies: ["DungeonCore"]),
    ]
)
