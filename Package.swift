// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrivateLink",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "PrivateLink",
            path: "Sources"
        )
    ]
)
