import Foundation

/// Every tunable the user can change, as one value type.
///
/// This is the single source of the app's settings. The macOS layer is responsible for
/// persisting it (`UserDefaults`) and for the API key, which lives in the Keychain and is
/// deliberately not part of this type.
public struct Settings: Equatable, Sendable {
  /// The keyboard chord that starts and stops a session.
  ///
  /// Stored as a keycode plus modifiers rather than a string so that adding presets, or a
  /// recorder UI later, does not change the storage format.
  public struct Hotkey: Equatable, Sendable {
    /// A virtual keycode, in the same space as `kVK_ANSI_D` and friends.
    public var keyCode: UInt16
    public var modifiers: ModifierFlags

    public init(keyCode: UInt16, modifiers: ModifierFlags) {
      self.keyCode = keyCode
      self.modifiers = modifiers
    }

    /// Opt+D. `0x02` is `kVK_ANSI_D`.
    public static let optionD = Hotkey(keyCode: 0x02, modifiers: .option)
  }

  public struct ModifierFlags: OptionSet, Equatable, Sendable {
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
  public var keyterms: [String]

  /// BCP-47 language tag passed to the transcription API.
  public var language: String

  /// Seconds without transcript activity before the session shows its paused state. Nothing is
  /// ever inserted on this timeout; it only changes what the overlay renders.
  public var silenceTimeout: TimeInterval

  /// Seconds after which a session ends and inserts whatever has accumulated, for the case
  /// where the user walks away.
  public var hardCap: TimeInterval

  /// The chosen audio input device. `nil` means follow the system default input, so connecting
  /// AirPods does the obvious thing.
  public var inputDeviceID: String?

  public init(
    hotkey: Hotkey = .optionD,
    keyterms: [String] = [],
    language: String = "en",
    silenceTimeout: TimeInterval = 10,
    hardCap: TimeInterval = 600,
    inputDeviceID: String? = nil
  ) {
    self.hotkey = hotkey
    self.keyterms = keyterms
    self.language = language
    self.silenceTimeout = silenceTimeout
    self.hardCap = hardCap
    self.inputDeviceID = inputDeviceID
  }
}
