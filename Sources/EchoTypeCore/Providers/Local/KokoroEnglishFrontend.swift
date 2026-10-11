import FluidAudio
import Foundation
import libespeak_ng

/// eSpeak has process-global state. Keep initialization, voice selection and conversion
/// on one actor, including concurrent readings with different accents.
actor KokoroEnglishFrontend {
  static let shared = KokoroEnglishFrontend()
  private var initialized = false

  func phonemes(for text: String, voice: String) throws -> String {
    try initialize()
    guard espeak_SetVoiceByName(voice.hasPrefix("b") ? "en" : "en-us") == EE_OK else {
      throw ProviderError.failed("Could not select the English pronunciation voice.")
    }
    // Retain pause punctuation rather than relying on eSpeak's clause terminators.
    // The web demo also sends the runs between punctuation to eSpeak individually.
    let punctuation = CharacterSet(charactersIn: ";:,.!?¡¿—…\"«»“”(){}[]")
    var result = ""
    var run = ""
    for character in text.replacingOccurrences(of: "’", with: "'") {
      if character.unicodeScalars.allSatisfy({ punctuation.contains($0) }) {
        result += try convert(run) + String(character)
        run = ""
      } else {
        run.append(character)
      }
    }
    result += try convert(run)
    return Self.adapt(result, british: voice.hasPrefix("b"))
  }

  private func convert(_ text: String) throws -> String {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
    return try text.withCString { input in
      var cursor: UnsafeRawPointer? = UnsafeRawPointer(input)
      var parts: [String] = []
      while cursor != nil {
        let previous = cursor
        // Tie multi-symbol phonemes with ^ so diphthongs can be mapped unambiguously.
        let mode = Int32(espeakPHONEMES_IPA) | 0x80 | (94 << 8)
        guard let output = espeak_TextToPhonemes(&cursor, Int32(espeakCHARS_UTF8), mode) else {
          throw ProviderError.failed("English pronunciation conversion failed.")
        }
        parts.append(String(cString: output))
        guard cursor != previous else { throw ProviderError.failed("English pronunciation conversion stalled.") }
      }
      return parts.joined(separator: " ")
    }
  }

  /// Our v1.0 weights expect Misaki's alphabet, unlike the demo's older ONNX model.
  /// Follow upstream Misaki's eSpeak-to-English conversion for that alphabet.
  static func adapt(_ phonemes: String, british: Bool) -> String {
    var result = phonemes
    let substitutions = [
      ("ʔˌn\u{0329}", "ʔn"), ("ʔn\u{0329}", "ʔn"),
      ("a^ɪ", "I"), ("a^ʊ", "W"), ("d^ʒ", "ʤ"), ("e^ɪ", "A"),
      ("t^ʃ", "ʧ"), ("ɔ^ɪ", "Y"), ("ə^l", "ᵊl"),
      ("ʲo", "jo"), ("ʲə", "jə"), ("ʲ", ""), ("ɚ", "əɹ"),
      ("r", "ɹ"), ("x", "k"), ("ç", "k"), ("ɐ", "ə"), ("ɬ", "l"),
      ("\u{0303}", ""), ("e", "A"),
    ]
    for (source, target) in substitutions { result = result.replacingOccurrences(of: source, with: target) }
    result = result.replacingOccurrences(of: #"(\S)\u0329"#, with: "ᵊ$1", options: .regularExpression)
      .replacingOccurrences(of: "\u{0329}", with: "")
    if british {
      result = result.replacingOccurrences(of: "A^ə", with: "ɛː")
        .replacingOccurrences(of: "iə", with: "ɪə")
        .replacingOccurrences(of: "ə^ʊ", with: "Q")
    } else {
      result = result.replacingOccurrences(of: "o^ʊ", with: "O")
        .replacingOccurrences(of: "ɜːɹ", with: "ɜɹ")
        .replacingOccurrences(of: "ɜː", with: "ɜɹ")
        .replacingOccurrences(of: "ɪə", with: "iə")
        .replacingOccurrences(of: "ː", with: "")
    }
    return result.replacingOccurrences(of: "o", with: "ɔ")
      .replacingOccurrences(of: "ɾ", with: "T")
      .replacingOccurrences(of: "ʔ", with: "t")
      .replacingOccurrences(of: "^", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The low-level synthesis API does not split overlong phoneme sequences.
  static func chunks(_ phonemes: String) -> [String] {
    var rest = phonemes.unicodeScalars[...]
    var chunks: [String] = []
    while !rest.isEmpty {
      let bound = rest.index(rest.startIndex, offsetBy: min(rest.count, KokoroAneConstants.maxPhonemeLength))
      let head = rest[..<bound]
      let boundary = head.lastIndex { $0.properties.isWhitespace || ",;:.!?".unicodeScalars.contains($0) }
      let end = bound == rest.endIndex ? bound : boundary.map { rest.index(after: $0) } ?? bound
      let chunk = String(rest[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
      if !chunk.isEmpty { chunks.append(chunk) }
      rest = rest[end...].drop { $0.properties.isWhitespace }
    }
    return chunks
  }

  private func initialize() throws {
    guard !initialized else { return }
    let root = try Self.resourceRoot()
    guard espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, 0, root.path, Int32(espeakINITIALIZE_DONT_EXIT)) > 0 else {
      throw ProviderError.failed("Could not initialize English pronunciation.")
    }
    initialized = true
  }

  /// Bundle.module uses the same generated pronunciation data in the app and tests.
  static func resourceRoot() throws -> URL {
    guard let root = Bundle.module.url(forResource: "EnglishPronunciation", withExtension: "bundle") else {
      throw ProviderError.failed("The English pronunciation resource bundle is missing.")
    }
    for name in ["en_dict", "phondata", "phonindex", "phontab", "intonations"] {
      guard FileManager.default.fileExists(atPath: root.appending(path: "espeak-ng-data/\(name)").path) else {
        throw ProviderError.failed("The English pronunciation data is incomplete.")
      }
    }
    return root
  }
}
