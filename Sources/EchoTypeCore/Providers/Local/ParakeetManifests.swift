/// The pinned models Parakeet Unified transcription loads, each from the repository FluidAudio
/// converted it into. Each lists only the files FluidAudio reads: every file inside the
/// `.mlmodelc` bundles named in `ParakeetModel`, plus the vocabulary and tokenizer.
enum ParakeetManifests {
  /// The streaming encoder at the 640 ms configuration (70 frames of left context, 560 ms chunks,
  /// 80 ms of look-ahead), INT8, with the decoder, the single-step joint and the vocabulary.
  ///
  /// The conversion's card says CC-BY-4.0, but the upstream model, `nvidia/parakeet-unified-en-0.6b`,
  /// is governed by the NVIDIA Open Model License, so that is recorded: the two conflict.
  static let unified = ModelManifest(
    name: "parakeet-unified-en-0.6b-640ms-int8", repository: "FluidInference/parakeet-unified-en-0.6b-coreml",
    revision: "d32e972dd4315f1dc3f6be28fb2aab0ab3e80358", license: "NVIDIA-Open-Model-License",
    files: [
        .init(
          path: "parakeet_unified_decoder.mlmodelc/analytics/coremldata.bin", size: 243,
          sha256: "9ae70f6559989f88b856b326e59315798f9f0d08207a19fcc2dd3287a30088a5"),
        .init(
          path: "parakeet_unified_decoder.mlmodelc/coremldata.bin", size: 560,
          sha256: "ce99c4488840fc463d59f8d4d6d2a9e8ceae8138ead51e3c265dde4d2ba4a0e9"),
        .init(
          path: "parakeet_unified_decoder.mlmodelc/model.mil", size: 13102,
          sha256: "6e60965b89c93943aa2be2d991c2461108145851fde05e1d048223a32d4cb20d"),
        .init(
          path: "parakeet_unified_decoder.mlmodelc/weights/weight.bin", size: 14_429_952,
          sha256: "96f990461a5986d5e7309ad1a0f36084fbf0f4b28aec35948f8b8d0dcbf8599e"),
        .init(
          path: "parakeet_unified_encoder_streaming_70_7_1_int8.mlmodelc/analytics/coremldata.bin", size: 243,
          sha256: "532a29eef8fb961a6670b82912bcfba6c5969de5f2a444192df917ba6f68ba24"),
        .init(
          path: "parakeet_unified_encoder_streaming_70_7_1_int8.mlmodelc/coremldata.bin", size: 513,
          sha256: "aebf6dec20848b9d6412e8a6643925479159314fcbee15ea0363350ce9fe732b"),
        .init(
          path: "parakeet_unified_encoder_streaming_70_7_1_int8.mlmodelc/model.mil", size: 928_896,
          sha256: "6a26ecda0a7c19e0caec5640ac3c49c2111496e63230ec9e146f391f10f456e8"),
        .init(
          path: "parakeet_unified_encoder_streaming_70_7_1_int8.mlmodelc/weights/weight.bin", size: 589_683_392,
          sha256: "4d2056957de09ac202ffd17127e32acfe7e8c381978bf727400de64f88c7c4ff"),
        .init(
          path: "parakeet_unified_joint_decision_single_step.mlmodelc/analytics/coremldata.bin", size: 243,
          sha256: "163877ad14af97ec4107cd854fd1c6d336ee5d40ad25a657cc764fb763f452f5"),
        .init(
          path: "parakeet_unified_joint_decision_single_step.mlmodelc/coremldata.bin", size: 556,
          sha256: "68a081570a48b52ec9379e153bd56748a5408a50be16767601563f231eaeff03"),
        .init(
          path: "parakeet_unified_joint_decision_single_step.mlmodelc/model.mil", size: 9611,
          sha256: "03c21096090bcd0b71c896c5ae0eb815db31a91c6676f572a7868eee4299abe3"),
        .init(
          path: "parakeet_unified_joint_decision_single_step.mlmodelc/weights/weight.bin", size: 3_446_978,
          sha256: "06831afa6d1beb0c0b10350ebf7886bc37638e951d14e738d7e06fbd2a05012f"),
        .init(
          path: "vocab.json", size: 15088,
          sha256: "e1a7bff4f5df133c0f4ad47b8e43c96f6bf1865d99126a4c4725ef51d0108bec"),
    ])

  /// The Silero voice activity model `VadManager` loads, at the 256 ms chunk size. The
  /// conversion and upstream (`snakers4/silero-vad`) are both MIT.
  static let voiceActivity = ModelManifest(
    name: "silero-vad-256ms-v6.2.1", repository: "FluidInference/silero-vad-coreml",
    revision: "b419383c55c110e2c9271fa6ee0ea83d03c70d96", license: "MIT",
    files: [
        .init(
          path: "silero-vad-unified-256ms-v6.2.1.mlmodelc/analytics/coremldata.bin", size: 243,
          sha256: "8067594eb3126ab8318af507f0c00cabfed40d5fedb8a0ee5075dd02e903d909"),
        .init(
          path: "silero-vad-unified-256ms-v6.2.1.mlmodelc/coremldata.bin", size: 625,
          sha256: "7db35a4fd995222a7fb0129713473b15d1462572ab4a2e5e4d56bcaad9e40f41"),
        .init(
          path: "silero-vad-unified-256ms-v6.2.1.mlmodelc/metadata.json", size: 3335,
          sha256: "2740be542c611e1ba358e1849b4e265c65cdf0b17192767e1e5de86a31ac94d6"),
        .init(
          path: "silero-vad-unified-256ms-v6.2.1.mlmodelc/model.mil", size: 176_918,
          sha256: "c6a9d1bf22d413265da0a07a1d14151c3ea2fad296b3aa5859275b33ef1c3270"),
        .init(
          path: "silero-vad-unified-256ms-v6.2.1.mlmodelc/weights/weight.bin", size: 882_304,
          sha256: "53ecc8b5081146140ab654c89109cf001f2183abddd7a2411c5081feeffff063"),
    ])

  /// The CTC model loaded with Parakeet to spot saved keyterms in the audio. It ships the
  /// mel stage, the encoder with its CTC head, and the tokenizer boosting needs. The
  /// conversion and upstream (`nvidia/parakeet-tdt_ctc-110m`) are both CC-BY-4.0.
  static let keywordSpotting = ModelManifest(
    name: "parakeet-ctc-110m", repository: "FluidInference/parakeet-ctc-110m-coreml",
    revision: "accdafd8cf8a2ff1cabe3c11e54416b405d409aa", license: "CC-BY-4.0",
    files: [
        .init(
          path: "AudioEncoder.mlmodelc/analytics/coremldata.bin", size: 243,
          sha256: "8906c823e9bb3bf6b16d9f0308f98cd70573526333ad85dd767dc3f9ae6b25fa"),
        .init(
          path: "AudioEncoder.mlmodelc/coremldata.bin", size: 505,
          sha256: "a88b002b58193b4c31211754cdfdf220a85f9651dc61caf336ab84400cbc191a"),
        .init(
          path: "AudioEncoder.mlmodelc/metadata.json", size: 3456,
          sha256: "4f288bfe5cbe867ef1e592cdae33578b2fe59ada69182fc12209879558f985c2"),
        .init(
          path: "AudioEncoder.mlmodelc/model.mil", size: 1_060_924,
          sha256: "2f84ef93a69115e55f3b5d8ce695b3c937de1833d4d229620634fae967cd587e"),
        .init(
          path: "AudioEncoder.mlmodelc/weights/weight.bin", size: 100_778_304,
          sha256: "af0734b4a5d7465ad9e8bb170f0c53c5e6b91ebb75a9bdf88d3f59ae4ad6aebd"),
        .init(
          path: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", size: 243,
          sha256: "22f2a8cba1de25c984050566b534a1d8caf22a82f9fe6c1c6f3149a0dd7e8ae3"),
        .init(
          path: "MelSpectrogram.mlmodelc/coremldata.bin", size: 330,
          sha256: "3a32ec67c76aa0aa2faef518413c311493e89aeb7fa11289fa4b8653ab8a160c"),
        .init(
          path: "MelSpectrogram.mlmodelc/metadata.json", size: 1962,
          sha256: "5e11d21a65c02bcfc37db43e941978e5d60d59e0efeadfda08e41f33b4f835d3"),
        .init(
          path: "MelSpectrogram.mlmodelc/model.mil", size: 12584,
          sha256: "0a7cb5693b39667295218bac5c7c09053f6bcd4b32699a83d06ac35d14ac6b79"),
        .init(
          path: "MelSpectrogram.mlmodelc/weights/weight.bin", size: 567_712,
          sha256: "0a89c055bfde9022029d3cc59a23e949385e063974460d8eaec3a7614c3eaaa8"),
        .init(
          path: "tokenizer.json", size: 360_106,
          sha256: "9f7c517c0bf644b1b690ab037bab4d4c53aecd38e047e7154d011013ab9160db"),
        .init(
          path: "vocab.json", size: 16086,
          sha256: "319d386eead79aadc80df9c3ecc8340d1a727efb7c02a8847eb940380dd61e1f"),
    ])
}
