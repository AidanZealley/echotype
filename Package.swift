// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "EchoType",
  platforms: [.macOS(.v26)],
  dependencies: [
    // On-device cleanup for the experimental local provider. MLX Swift LM has no tag at the
    // revision research verified against Swift 6.4, so it is pinned by commit, and MLX Swift to
    // the release it was built with. swift-transformers supplies the tokenizer and chat template.
    .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.32.3"),
    .package(
      url: "https://github.com/ml-explore/mlx-swift-lm", revision: "5e46681b2adcef2db158e7b949aeae3896778e23"),
    .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.4"),
  ],
  targets: [
    // Session and protocol code without AppKit or TCC. Tests use an injected clock and
    // recorded event streams instead of a signed bundle or a live socket.
    .target(
      name: "EchoTypeCore",
      dependencies: [
        .product(name: "MLX", package: "mlx-swift"),
        .product(name: "MLXLLM", package: "mlx-swift-lm"),
        .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
        .product(name: "Tokenizers", package: "swift-transformers"),
      ]),
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
