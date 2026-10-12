// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrivateBeacon",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "PrivateBeacon",
            path: "Sources"
        )
    ]
)
