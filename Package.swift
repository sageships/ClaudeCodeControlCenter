// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeControlCenter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeCodeControlCenter", targets: ["ClaudeCodeControlCenter"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeControlCenter",
            path: "ClaudeCodeControlCenter"
        )
    ]
)
