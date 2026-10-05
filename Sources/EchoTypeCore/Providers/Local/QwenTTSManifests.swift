import Foundation

/// The pinned files Qwen3-TTS CustomVoice loads through MLX Audio Swift, laid out as in the
/// conversion's repository: the talker's configuration and weights, the text tokenizer's slow
/// files (`vocab.json`, `merges.txt`, `tokenizer_config.json`) and the 12 Hz speech tokenizer
/// (the codec) under `speech_tokenizer/`. The list is what `Qwen3TTSModel.fromModelDirectory`
/// reads; it ignores the generation, preprocessor and index files.
///
/// Apache 2.0: each conversion's card says so, as does its upstream (`Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`
/// and `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`). The two share every file but the talker's
/// `config.json` and weights.
enum QwenTTSManifests {
  static let large = manifest(
    name: "qwen3-tts-12hz-1.7b-customvoice-4bit", repository: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit",
    revision: "f35faf19b0cc2160865af64ecf0f22f83d335135",
    config: .init(
      path: "config.json", size: 6058, sha256: "5a1dd8d7c9f4d04d5bdac309e9e748f16a96b0724d9c4de4974982dd84078715"),
    weights: .init(
      path: "model.safetensors", size: 1_625_226_859,
      sha256: "45a5b5ccd3cc473b9d3890ea922937036b56b948e8bd8c678e725329abdd1d00"))

  static let small = manifest(
    name: "qwen3-tts-12hz-0.6b-customvoice-4bit", repository: "mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-4bit",
    revision: "08c72cad5e2fd0f41730c8bd1f28149585e46361",
    config: .init(
      path: "config.json", size: 6058, sha256: "612cb591b44547319e5c68a78c0e93e4defb57882a4aa9ef5f06cc2f071ed036"),
    weights: .init(
      path: "model.safetensors", size: 1_006_772_520,
      sha256: "4ab02a20be381700f6e73dbb5efdc424cadf9f1d0652cbffd662872ea41e296a"))

  private static func manifest(
    name: String, repository: String, revision: String, config: ModelManifest.File, weights: ModelManifest.File
  ) -> ModelManifest {
    ModelManifest(
      name: name, repository: repository, revision: revision, license: "Apache-2.0",
      files: [
        config,
        weights,
        .init(
          path: "tokenizer_config.json", size: 7344,
          sha256: "dc3c31c3bdaedd5016382bb3cbe07323026775ad51f5a4fb564505992ae4a670"),
        .init(
          path: "vocab.json", size: 2_776_833,
          sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"),
        .init(
          path: "merges.txt", size: 1_671_839,
          sha256: "599bab54075088774b1733fde865d5bd747cbcc7a547c5bc12610e874e26f5e3"),
        .init(
          path: "speech_tokenizer/config.json", size: 2336,
          sha256: "ee65bb901c876664ab8707c487157aa1a6ee57c65969b28fb5ec9dc211e68167"),
        .init(
          path: "speech_tokenizer/model.safetensors", size: 682_293_092,
          sha256: "836b7b357f5ea43e889936a3709af68dfe3751881acefe4ecf0dbd30ba571258"),
      ])
  }
}
