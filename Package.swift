// swift-tools-version: 6.2

import PackageDescription

// EchoTypeApp imports AppKit and SwiftUI, so it cannot compile on Linux. Dropping it
// there is what keeps `swift build` and `swift test` working for EchoTypeCore on the
// remote machine.
var targets: [Target] = [
  .target(name: "EchoTypeCore"),
  .testTarget(name: "EchoTypeCoreTests", dependencies: ["EchoTypeCore"]),
]

#if !os(Linux)
  targets.append(
    // Built into a signed .app bundle by scripts/run.sh, which is the only supported
    // way to launch it.
    .executableTarget(name: "EchoTypeApp")
  )
#endif

let package = Package(
  name: "EchoType",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "EchoTypeCore", targets: ["EchoTypeCore"])
  ],
  targets: targets
)
