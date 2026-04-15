// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SSHub",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SSHub",
            targets: ["SSHub"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SSHub",
            path: "Sources"
        ),
        .testTarget(
            name: "SSHubTests",
            dependencies: ["SSHub"],
            path: "Tests/SSHubTests"
        )
    ]
)
