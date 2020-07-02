// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "WebRTC",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "WebRTC",
            targets: ["WebRTCFramework"]),
    ],
    dependencies: [ ],
    targets: [
        .binaryTarget(
            name: "WebRTCFramework",
            url: "https://www.dropbox.com/s/qb4d0mwr1mvdl56/WebRTC.xcframework.zip?dl=1",
            checksum: "f31285485f4b4aa26fd0861b957a5356a7ded4279bcc5fce8fbc33d10e18028f"
        ),
    ]
)
