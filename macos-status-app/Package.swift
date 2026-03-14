// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "LocalBridge",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "LocalBridge",
      targets: ["LocalBridge"]
    )
  ],
  targets: [
    .executableTarget(
      name: "LocalBridge",
      path: "Sources/LocalBridge"
    )
  ]
)
