import Foundation

/// Every tunable the user can change, as one value type.
///
/// This is the single source of the app's settings. The macOS layer stores `encoded()` in
/// `UserDefaults` and keeps the API key in the Keychain; the key is deliberately not part of
/// this type.
public struct Settings: Equatable, Sendable {
  /// The keyboard chord that starts and stops a session.
  ///
  /// Stored as a keycode plus modifiers rather than a string so that adding presets, or a
  /// recorder UI later, does not change the storage format.
  public struct Hotkey: Hashable, Sendable, Codable {
    /// A virtual keycode, in the same space as `kVK_ANSI_D` and friends.
    public var keyCode: UInt16
    public var modifiers: ModifierFlags

    public init(keyCode: UInt16, modifiers: ModifierFlags) {
      self.keyCode = keyCode
      self.modifiers = modifiers
    }

    /// Opt+D. `0x02` is `kVK_ANSI_D`.
    public static let optionD = Hotkey(keyCode: 0x02, modifiers: .option)

    /// Ctrl+Opt+D, for when some app claims Opt+D. Ctrl+Opt is VoiceOver's modifier, which is
    /// why this is not the default.
    public static let controlOptionD = Hotkey(keyCode: 0x02, modifiers: [.control, .option])

    /// The chords the settings window offers for dictation.
    public static let presets = [optionD, controlOptionD]

    /// Opt+S, the read-aloud default. `0x01` is `kVK_ANSI_S`.
    public static let optionS = Hotkey(keyCode: 0x01, modifiers: .option)

    /// Ctrl+Opt+S, mirroring the dictation alternative.
    public static let controlOptionS = Hotkey(keyCode: 0x01, modifiers: [.control, .option])

    /// The chords the settings window offers for reading aloud.
    public static let readAloudPresets = [optionS, controlOptionS]

    /// Whether a key press is this chord: the same key, with the configured modifiers held and
    /// no others, so Cmd+Opt+D and Ctrl+Opt+D pass through an Opt+D hotkey untouched.
    public func matches(keyCode: UInt16, modifiers: ModifierFlags) -> Bool {
      keyCode == self.keyCode && modifiers == self.modifiers
    }
  }

  /// Stored as its raw value, so these bit positions are part of the stored format.
  public struct ModifierFlags: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    public static let shift = ModifierFlags(rawValue: 1 << 0)
    public static let control = ModifierFlags(rawValue: 1 << 1)
    public static let option = ModifierFlags(rawValue: 1 << 2)
    public static let command = ModifierFlags(rawValue: 1 << 3)
  }

  public var hotkey: Hotkey

  /// Domain terms sent to the transcription API to improve accuracy on jargon.
  ///
  /// The endpoint accepts up to 100, and they are the highest-value accuracy lever available:
  /// without them the model hears "shad CN" and "Zoo stand". `STTConnection.keyterms(settings:)`
  /// enforces the caps.
  public var keyterms: [String]

  /// BCP-47 language tag passed to the transcription API.
  public var language: String

  /// Seconds without transcript activity before the session shows its paused state. Nothing is
  /// ever inserted on this timeout; it only changes what the overlay renders.
  public var silenceTimeout: TimeInterval

  /// Seconds after which a session ends and inserts whatever has accumulated, for the case
  /// where the user walks away.
  public var hardCap: TimeInterval

  /// Seconds allowed from entering finishing to drain capture, send queued audio and
  /// `finalize`/`audio.done` in order, and receive the final `transcript.done`.
  /// Expiry fails the session while preserving committed text.
  public var finalizeTimeout: TimeInterval

  /// The chosen audio input device. `nil` means follow the system default input, so connecting
  /// AirPods does the obvious thing.
  public var inputDeviceID: String?

  /// Whether committed dictation is revised as it arrives.
  public var cleanUp: Bool

  /// The chord that reads the selection aloud, and stops a reading.
  public var readAloudHotkey: Hotkey

  /// The text to speech voice id, one of `Speech.voices`.
  public var voice: String

  /// The speaking rate, from 0.7 to 1.5, the endpoint's range.
  public var speechSpeed: Double

  public static let speechSpeedRange = 0.7...1.5
  public static let defaultSpeechSpeed = 1.0

  /// Storage and speech requests share this fallback, including for programmatic values.
  public var validatedSpeechSpeed: Double {
    Self.speechSpeedRange.contains(speechSpeed) && speechSpeed.isFinite
      ? speechSpeed : Self.defaultSpeechSpeed
  }

  /// Whether a dictation ending in a request like "reply with EchoType" is sent with Return.
  public var sendReplyRequests: Bool

  public init(
    hotkey: Hotkey = .optionD,
    keyterms: [String] = [],
    language: String = "en",
    silenceTimeout: TimeInterval = 10,
    hardCap: TimeInterval = 300,
    finalizeTimeout: TimeInterval = 8,
    inputDeviceID: String? = nil,
    cleanUp: Bool = true,
    readAloudHotkey: Hotkey = .optionS,
    voice: String = "ara",
    speechSpeed: Double = Settings.defaultSpeechSpeed,
    sendReplyRequests: Bool = true
  ) {
    self.hotkey = hotkey
    self.keyterms = keyterms
    self.language = language
    self.silenceTimeout = silenceTimeout
    self.hardCap = hardCap
    self.finalizeTimeout = finalizeTimeout
    self.inputDeviceID = inputDeviceID
    self.cleanUp = cleanUp
    self.readAloudHotkey = readAloudHotkey
    self.voice = voice
    self.speechSpeed = speechSpeed
    self.sendReplyRequests = sendReplyRequests
  }
}

// MARK: Storage

/// The stored form. Only the fields the settings window edits are persisted; the timeouts stay
/// code defaults so today's values are not frozen into every install.
///
/// The key names and the hotkey's shape are the upgrade contract: renaming one would reset
/// that setting on every existing install. Each field decodes on its own and falls back to its
/// default, so adding a field later, or one unreadable field, never resets the others.
extension Settings: Codable {
  private enum CodingKeys: String, CodingKey {
    case hotkey, keyterms, language, inputDeviceID, cleanUp
    case readAloudHotkey, voice, speechSpeed, sendReplyRequests
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = Settings()
    self = defaults
    hotkey = (try? container.decodeIfPresent(Hotkey.self, forKey: .hotkey)) ?? defaults.hotkey
    keyterms =
      (try? container.decodeIfPresent([String].self, forKey: .keyterms)) ?? defaults.keyterms
    language =
      (try? container.decodeIfPresent(String.self, forKey: .language)) ?? defaults.language
    inputDeviceID = try? container.decodeIfPresent(String.self, forKey: .inputDeviceID)
    cleanUp =
      (try? container.decodeIfPresent(Bool.self, forKey: .cleanUp)) ?? defaults.cleanUp
    readAloudHotkey =
      (try? container.decodeIfPresent(Hotkey.self, forKey: .readAloudHotkey))
      ?? defaults.readAloudHotkey
    voice = (try? container.decodeIfPresent(String.self, forKey: .voice)) ?? defaults.voice
    speechSpeed =
      (try? container.decodeIfPresent(Double.self, forKey: .speechSpeed)) ?? defaults.speechSpeed
    speechSpeed = validatedSpeechSpeed
    sendReplyRequests =
      (try? container.decodeIfPresent(Bool.self, forKey: .sendReplyRequests))
      ?? defaults.sendReplyRequests
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hotkey, forKey: .hotkey)
    try container.encode(keyterms, forKey: .keyterms)
    try container.encode(language, forKey: .language)
    try container.encodeIfPresent(inputDeviceID, forKey: .inputDeviceID)
    try container.encode(cleanUp, forKey: .cleanUp)
    try container.encode(readAloudHotkey, forKey: .readAloudHotkey)
    try container.encode(voice, forKey: .voice)
    try container.encode(validatedSpeechSpeed, forKey: .speechSpeed)
    try container.encode(sendReplyRequests, forKey: .sendReplyRequests)
  }

  /// Decodes a stored value. Missing or unreadable data gives the defaults.
  public init(decoding data: Data?) {
    self = data.flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
  }

  /// The value to store.
  public func encoded() -> Data {
    // The only persisted double is validated before encoding; the other fields always encode.
    try! JSONEncoder().encode(self)
  }
}
