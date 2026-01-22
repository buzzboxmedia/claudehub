// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeHub",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // No external dependencies - using Terminal.app for terminal emulation
    ],
    targets: [
        .executableTarget(
            name: "ClaudeHub",
            dependencies: [],
            path: "ClaudeHub",
            resources: [.copy("Resources/AppIcon.icns")]
        )
    ]
)
