// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "HonoStatusApp",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "HonoStatusApp",
      targets: ["HonoStatusApp"]
    )
  ],
  targets: [
    .executableTarget(
      name: "HonoStatusApp"
    )
  ]
)
