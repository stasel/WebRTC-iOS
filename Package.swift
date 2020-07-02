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
            url: "https://www.dropbox.com/s/r6hod7j8m2ruico/WebRTC.xcframework.zip?dl=1",
            checksum: "9c6a06509d67a842542855f0d63580cffe2b9e35eea1af9da07c1540f79fc64a"
        ),
    ]
)
