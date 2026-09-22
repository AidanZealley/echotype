// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EchoType",
    platforms: [.macOS(.v26)],
    targets: [
        // Built into a signed .app bundle by scripts/run.sh, which is the only
        // supported way to launch it.
        .executableTarget(name: "EchoTypeApp")
    ]
)
