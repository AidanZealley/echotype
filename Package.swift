// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "EchoType",
  products: [
    .library(name: "EchoTypeCore", targets: ["EchoTypeCore"])
  ],
  targets: [
    .target(name: "EchoTypeCore"),
    .testTarget(name: "EchoTypeCoreTests", dependencies: ["EchoTypeCore"]),
  ]
)
