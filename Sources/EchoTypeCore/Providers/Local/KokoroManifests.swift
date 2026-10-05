import Foundation

/// The pinned files Kokoro read aloud loads, all from FluidAudio's conversion repository and laid
/// out as it is there: the seven-stage English ANE chain under `ANE/` with its vocabulary and the
/// pre-converted Heart voice pack, Emma's Kokoro-82M v1.0 JSON voice pack under `voices/`, and the
/// English G2P resources at the root (the BART fallback model, its vocabulary and the Misaki US
/// lexicon). The list comes from what `KokoroAneModelStore.loadIfNeeded`, `G2PModel` and the
/// English frontend read, not from the downloader's defaults.
enum KokoroManifests {
  /// Apache 2.0: the conversion's card says so, as does the upstream `hexgrad/Kokoro-82M`, whose
  /// voice packs these are; `ANE/LICENSE` is the Apache 2.0 text.
  static let english = ModelManifest(
    name: "kokoro-82m-ane-en", repository: "FluidInference/kokoro-82m-coreml",
    revision: "006395f65025af251858b1ab0a7178a6a1e73f9f", license: "Apache-2.0",
    files: [
      .init(
        path: "ANE/KokoroAlbert.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "14a61873d8759a38b79c93f9021ae865f408f56301209a0168dbfc2283265ccd"),
      .init(
        path: "ANE/KokoroAlbert.mlmodelc/coremldata.bin", size: 433,
        sha256: "70b6d2f8429229f6800dda9480341669f7ac0eabf05a82934d8632ab2b4b63a6"),
      .init(
        path: "ANE/KokoroAlbert.mlmodelc/metadata.json", size: 2480,
        sha256: "fe1d005481f646707a948267ac089dfb2cd2ccea7d5827a14c28587eb4c89930"),
      .init(
        path: "ANE/KokoroAlbert.mlmodelc/model.mil", size: 101_485,
        sha256: "2038154d06a20e399a8ae35ec5c9242702cb23db8dd24dde7679cd53708e4eae"),
      .init(
        path: "ANE/KokoroAlbert.mlmodelc/weights/weight.bin", size: 5_718_848,
        sha256: "36089a39359b800d3e2c60e5e8ac9217d8f2d1010a8b9273192290e621f1fabc"),
      .init(
        path: "ANE/KokoroAlignment.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "f6074d1039a9151d0f97dc6ec9ee0cd9c7b865f1af646d718ab38b659fa84f3f"),
      .init(
        path: "ANE/KokoroAlignment.mlmodelc/coremldata.bin", size: 484,
        sha256: "9a0fb4a536f665a052914d7f17b0e6ac80a3614f702e4be87ac0302c1143a4ea"),
      .init(
        path: "ANE/KokoroAlignment.mlmodelc/metadata.json", size: 3021,
        sha256: "6f610d23b9f93c7f1a968d6a861efa99725a191de696bf1c3be334ead39b7f00"),
      .init(
        path: "ANE/KokoroAlignment.mlmodelc/model.mil", size: 8194,
        sha256: "eb3a618bda0cdf95cdffab586ef5c76333d0d0a1dcb881190b3ef414f3421b3e"),
      .init(
        path: "ANE/KokoroAlignment.mlmodelc/weights/weight.bin", size: 4128,
        sha256: "2e7d69128b59d615fc3d3cf85637a687235fc086b1eb136359adb11a61615f6b"),
      .init(
        path: "ANE/KokoroNoise_v2.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "53af6bf61482f6002bdb6e3a62f30774cde6e96411aebd888222a34b369f3d04"),
      .init(
        path: "ANE/KokoroNoise_v2.mlmodelc/coremldata.bin", size: 440,
        sha256: "9911047f924b41f8b92811c32c50b7c718bd7b0c14842b3bc1b66b9ffe341a19"),
      .init(
        path: "ANE/KokoroNoise_v2.mlmodelc/metadata.json", size: 3020,
        sha256: "eb3102217532d952479c6f1b04d26d7ac4cdbc59875b6a23e8aae86e5e02c2bc"),
      .init(
        path: "ANE/KokoroNoise_v2.mlmodelc/model.mil", size: 93152,
        sha256: "60233949d896f15ef38aea19afda558935d7569fa77a3ca4babddd3ffe845a36"),
      .init(
        path: "ANE/KokoroNoise_v2.mlmodelc/weights/weight.bin", size: 4_580_160,
        sha256: "1102fc2d31dfcfe3de3978a4c78b65202ff8b0a4d55a9304213bd4e8bda66bc2"),
      .init(
        path: "ANE/KokoroPostAlbert.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "6640044c875505382edbc361cdd56f3f1c30f082953e0f9473a31ae3f71e6c43"),
      .init(
        path: "ANE/KokoroPostAlbert.mlmodelc/coremldata.bin", size: 556,
        sha256: "86de3ab0c1e8c6f8842b57bc24695a5099590c49b864e3fa2737b1fb5b15ba3b"),
      .init(
        path: "ANE/KokoroPostAlbert.mlmodelc/metadata.json", size: 4171,
        sha256: "2e3be1af412a76e340120a01cd04a502666371ada86b1fdaf5a622896e0bf979"),
      .init(
        path: "ANE/KokoroPostAlbert.mlmodelc/model.mil", size: 60047,
        sha256: "450b73a3b179e1702e7b2210bad008eac20d58b2d6076e3c2de76290a66e5fef"),
      .init(
        path: "ANE/KokoroPostAlbert.mlmodelc/weights/weight.bin", size: 13_806_464,
        sha256: "e4f300a23cc2e05d38680d9fc94681cc722d445076d1d248f83255122ba091c8"),
      .init(
        path: "ANE/KokoroProsody_v2.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "804d7d2e9a8fed345cedb57da61bd27fdd95db22a070cfa7d42ccd4f8e80a443"),
      .init(
        path: "ANE/KokoroProsody_v2.mlmodelc/coremldata.bin", size: 421,
        sha256: "db8776a4896f690fd254cdb68a4551c168411c9b3fb98219630215bc3c357986"),
      .init(
        path: "ANE/KokoroProsody_v2.mlmodelc/model.mil", size: 73353,
        sha256: "e6acad9f44d70b1dba0aea6a5d25ee4edf68fe8f2933399ee81f70ace61cbc8b"),
      .init(
        path: "ANE/KokoroProsody_v2.mlmodelc/weights/weight.bin", size: 8_513_664,
        sha256: "70eea4cd2523992fa1fea840e31ab6f4fdd69c1598e220985a2ae6ea5da1e944"),
      .init(
        path: "ANE/KokoroTail_v2.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "a06e4b91c2b8a8be3ff701558a5f1f6484921f948202663fe6df78f248d42222"),
      .init(
        path: "ANE/KokoroTail_v2.mlmodelc/coremldata.bin", size: 392,
        sha256: "527271f6df56cc308a5f89374c92108aef7b837ab15f0ba4900d555588dbd905"),
      .init(
        path: "ANE/KokoroTail_v2.mlmodelc/metadata.json", size: 1872,
        sha256: "7708ecc145eecf8e3ef5ef8979ea7a4f77d04c8da787454c6d9190e5300fc50b"),
      .init(
        path: "ANE/KokoroTail_v2.mlmodelc/model.mil", size: 7014,
        sha256: "b0b8fd573bac76ba7eb85730eeb25538fc7f1c666ecbf939fd4b3a4ad4495ad7"),
      .init(
        path: "ANE/KokoroTail_v2.mlmodelc/weights/weight.bin", size: 81088,
        sha256: "8ede31ec20df7d86a124287ac12d13507651e2a693e9d4f35f0e7f92cba422c7"),
      .init(
        path: "ANE/KokoroVocoder.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "1cc4f1e6436597c6d458a845570d9d0ace458813ff90f225d08e0e713496b463"),
      .init(
        path: "ANE/KokoroVocoder.mlmodelc/coremldata.bin", size: 626,
        sha256: "71bac80d2f2f077fefc0d66cdc39c0faaa96540b3a6149093ef29de01b1f8764"),
      .init(
        path: "ANE/KokoroVocoder.mlmodelc/metadata.json", size: 4331,
        sha256: "a8e768f151225a52476d35f6ab90805ae00f1f78b83be4ca21327029c800c183"),
      .init(
        path: "ANE/KokoroVocoder.mlmodelc/model.mil", size: 309_000,
        sha256: "52f2febec45094e78a5948a3a47f023be8fc57cfd48cc99e8d4c358a13674ef2"),
      .init(
        path: "ANE/KokoroVocoder.mlmodelc/weights/weight.bin", size: 48_889_920,
        sha256: "6d1f96eb50218ab687b12d6d862d2ae854c12b7165c3cd9b6b5cef261ef02ff1"),
      .init(
        path: "ANE/af_heart.bin", size: 522_240,
        sha256: "d583ccff3cdca2f7fae535cb998ac07e9fcb90f09737b9a41fa2734ec44a8f0b"),
      .init(
        path: "ANE/vocab.json", size: 1416,
        sha256: "8d65b0188b77eafc60751dac42bbac7ab5f5685074af44db91d1877b42dc1d7c"),
      .init(
        path: "G2PDecoder.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "dbf1767747fdc188222d467a45b04608b396c76c71db3abb18a5fb3680ef9827"),
      .init(
        path: "G2PDecoder.mlmodelc/coremldata.bin", size: 545,
        sha256: "607e960f19b4d9a30317a5a11869fcce84b300a909fcab2cc756c0d98e2dacd9"),
      .init(
        path: "G2PDecoder.mlmodelc/metadata.json", size: 3064,
        sha256: "e54e98484fd60d26f22fd3c4e7fe87b0d92a5d2de1f958cc3c4bb36d4ae06a44"),
      .init(
        path: "G2PDecoder.mlmodelc/model.mil", size: 19737,
        sha256: "fe647c598e0d9454d360b8ee49a59ae57ca147fc5330863ba84ccb90dce482ad"),
      .init(
        path: "G2PDecoder.mlmodelc/weights/weight.bin", size: 828_030,
        sha256: "cbaeb4e743359f607ab161af0c6d8a817462fdaec622ee788ef8ef952c5f8214"),
      .init(
        path: "G2PEncoder.mlmodelc/analytics/coremldata.bin", size: 243,
        sha256: "cf7fbd7e7a65529b2d2bf3941e458a0ab6dff7a298bf48e205a1727c81c26a99"),
      .init(
        path: "G2PEncoder.mlmodelc/coremldata.bin", size: 398,
        sha256: "0f14d46ca9fd06c68b4717294575b2b99449e67d40b7a2c56f926bf05cd90b11"),
      .init(
        path: "G2PEncoder.mlmodelc/metadata.json", size: 2034,
        sha256: "c8e0cfd7f494ac1b3662ff8f1914b2b45f79ffb2791724cdc0576981996732e1"),
      .init(
        path: "G2PEncoder.mlmodelc/model.mil", size: 20392,
        sha256: "8c617e569f37286b056dad800d862dc145be9a95fa9ed43857bb646ba199d7da"),
      .init(
        path: "G2PEncoder.mlmodelc/weights/weight.bin", size: 694_592,
        sha256: "6926bcd2827d21fec82839487b987e06f85fd8a6a5bb896bc4f6062461d014ec"),
      .init(
        path: "g2p_vocab.json", size: 1665,
        sha256: "295ed64b86c2820cd665b0602ae50c6947c0e82ac643082873e0be87dca282ce"),
      .init(
        path: "us_lexicon_cache.json", size: 10_444_631,
        sha256: "6b36ba313202227d6914ad32cd684a0304bd2757e9ec4158ea7bc36ec40e224e"),
      .init(
        path: "voices/bf_emma.json", size: 2_679_667,
        sha256: "2b7f73a1af7bd195d1c4bae834cc96d4e319e26abb4ddbe4c7c43485789dda69"),
    ])
}
