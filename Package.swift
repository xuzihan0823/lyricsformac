// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LyricsFloat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LyricsFloat", targets: ["LyricsFloat"])
    ],
    targets: [
        .executableTarget(
            name: "LyricsFloat",
            path: "Sources/LyricsFloat"
        )
    ]
)
