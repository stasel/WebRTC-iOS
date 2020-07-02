// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "WebRTC",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "WebRTC",
            targets: ["WebRTC"]),
    ],
    dependencies: [ ],
    targets: [
        .binaryTarget(
            name: "WebRTC",
            url: "https://www.dropbox.com/s/dl/qb4d0mwr1mvdl56/WebRTC.xcframework.zip",
            checksum: "f31285485f4b4aa26fd0861b957a5356a7ded4279bcc5fce8fbc33d10e18028f"
        ),
    ]
)
