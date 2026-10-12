/// The supported local model set. Manifests own pinned files and the shared store owns downloads.
enum LocalModels {
  static let store = ModelStore()
  static let transcription = [ParakeetManifests.unified, ParakeetManifests.voiceActivity, ParakeetManifests.keywordSpotting]
  static let speech = [KokoroManifests.english]
  static let cleanup = ModelManifest(
      name: "qwen3-4b-instruct-2507-4bit", repository: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
      revision: "50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b", license: "Apache-2.0",
      files: [
        .init(
          path: "config.json", size: 938,
          sha256: "574349e5a343236546fda55e4744a76e181f534182d7dc60ff1bad7e7a502849"),
        .init(
          path: "generation_config.json", size: 238,
          sha256: "835fffe355c9438e7a25be099b3fccaa98350b83451f9fd2d99512e74f1ade48"),
        .init(
          path: "tokenizer_config.json", size: 5440,
          sha256: "4397cc477eb6d79715ccd2000accd6b3531928f30029665832fa1b255f24d2b9"),
        .init(
          path: "chat_template.jinja", size: 4040,
          sha256: "40c21f34cf67d8c760ef72f8ad3ae5afad514299d4b06e91dd9a8d705af7b541"),
        .init(
          path: "tokenizer.json", size: 11_422_654,
          sha256: "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"),
        .init(
          path: "model.safetensors", size: 2_263_022_417,
          sha256: "2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f"),
      ])
}

extension Provider {
  public static let local = LocalProvider.make()
}
