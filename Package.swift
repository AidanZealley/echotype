// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "EchoType",
  platforms: [.macOS(.v26)],
  targets: [
    // Session and protocol code without AppKit or TCC. Tests use an injected clock and
    // recorded event streams instead of a signed bundle or a live socket.
    .target(name: "EchoTypeCore"),
    // WAV reading and resampling for the bench and the live tests. Depended on only by those,
    // never by EchoTypeCore or EchoTypeApp.
    .target(name: "EchoTypeTestSupport"),
    .testTarget(name: "EchoTypeCoreTests", dependencies: ["EchoTypeCore", "EchoTypeTestSupport"]),
    // Built into a signed .app bundle by scripts/deploy.sh, through run.sh for development
    // or install.sh for /Applications. That is the only supported way to launch it.
    .executableTarget(name: "EchoTypeApp", dependencies: ["EchoTypeCore"]),
    .testTarget(name: "EchoTypeAppTests", dependencies: ["EchoTypeApp"]),
    // Developer tool that runs the corpus through providers. Never part of the app bundle.
    .executableTarget(name: "EchoTypeBench", dependencies: ["EchoTypeCore", "EchoTypeTestSupport"]),
    .testTarget(name: "EchoTypeBenchTests", dependencies: ["EchoTypeBench"]),
  ]
)
