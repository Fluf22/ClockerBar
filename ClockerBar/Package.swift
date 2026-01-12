// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClockerBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClockerBar",
            path: "Sources/ClockerBar"
        )
    ]
)
