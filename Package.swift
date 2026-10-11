// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "EchoType",
  platforms: [.macOS(.v26)],
  dependencies: [
    // Restore the cleanup runtime measured before the Qwen speech experiment forced older
    // MLX dependencies. Pin the evaluated revision; swift-transformers supplies its tokenizer.
    .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.32.3"),
    .package(
      url: "https://github.com/ml-explore/mlx-swift-lm", revision: "5e46681b2adcef2db158e7b949aeae3896778e23"),
    .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.4"),
    // On-device transcription and speech for the fixed local model set. The newest tag predates
    // Parakeet Unified, so it is pinned by the commit research verified against Swift 6.4.
    .package(
      url: "https://github.com/FluidInference/FluidAudio", revision: "0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7"),
    .package(url: "https://github.com/espeak-ng/espeak-ng-spm", revision: "fd28f6460cc4cdf631528c8e2f7bd825747aac5c"),
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
        .product(name: "FluidAudio", package: "FluidAudio"),
        .product(name: "libespeak-ng", package: "espeak-ng-spm"),
      ],
      plugins: [.plugin(name: "EnglishPronunciationPlugin")]),
    .executableTarget(
      name: "EnglishPronunciationBuilder",
      dependencies: [.product(name: "libespeak-ng", package: "espeak-ng-spm")],
      path: "scripts/speech-data-builder"),
    .plugin(
      name: "EnglishPronunciationPlugin", capability: .buildTool(),
      dependencies: ["EnglishPronunciationBuilder"]),
    // WAV reading and resampling for opt-in live tests. Depended on only by tests,
    // never by EchoTypeCore or EchoTypeApp.
    .target(name: "EchoTypeTestSupport"),
    .testTarget(name: "EchoTypeCoreTests", dependencies: ["EchoTypeCore", "EchoTypeTestSupport"]),
    // Built into a signed .app bundle by scripts/deploy.sh, through run.sh for development
    // or install.sh for /Applications. That is the only supported way to launch it.
    .executableTarget(name: "EchoTypeApp", dependencies: ["EchoTypeCore"]),
    .testTarget(name: "EchoTypeAppTests", dependencies: ["EchoTypeApp"]),
  ]
)
