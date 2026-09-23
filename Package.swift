// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "EchoType",
  platforms: [.macOS(.v26)],
  targets: [
    // No UI, no global state, no I/O. That is what keeps the whole suite running in
    // milliseconds against an injected clock and recorded event streams, rather than a
    // signed bundle and a real socket.
    .target(name: "EchoTypeCore"),
    .testTarget(name: "EchoTypeCoreTests", dependencies: ["EchoTypeCore"]),
    // Built into a signed .app bundle by scripts/run.sh, which is the only supported way
    // to launch it.
    .executableTarget(name: "EchoTypeApp"),
  ]
)
