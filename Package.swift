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
            url: "https://www.dropbox.com/s/2bshi6s9s9aimfa/WebRTC-2020-07-02T19-17-50.xcframework.zip?dl=1",
            checksum: "f2ee6b8945e7b73ffdaec754a5e96a286362b1891b75a44e37650ec0fbe6eb75"
        ),
    ]
)
