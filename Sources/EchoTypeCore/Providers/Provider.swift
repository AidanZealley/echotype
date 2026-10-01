import Foundation

// The neutral contracts every provider's adapters implement. Code outside `Providers/<Name>/`
// names no provider; it holds service values and talks to them only through these types.

/// A failure a provider reports, in the form the app words for the user.
public enum ProviderError: Error, Equatable, Sendable {
  case rejectedCredential
  case rateLimited
  case unavailable
  /// Anything else the provider reported, with its own description.
  case failed(String)
}

// MARK: Transcription

/// Live transcription. `start` opens one session; nothing is opened until it is called, since an
/// idle open session may be billed.
public struct TranscriptionService: Sendable {
  /// The most keyterms a session accepts, including the built-in one.
  public var keytermLimit: Int
  public var start: @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber

  public init(
    keytermLimit: Int,
    start: @escaping @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber
  ) {
    self.keytermLimit = keytermLimit
    self.start = start
  }
}

public struct TranscriptionRequest: Equatable, Sendable {
  /// BCP-47 language tag.
  public var language: String
  /// `EchoType` first, then the saved terms, cut to the service's `keytermLimit`.
  public var keyterms: [String]
  public var credential: String?

  public init(language: String, keyterms: [String], credential: String?) {
    self.language = language
    self.keyterms = keyterms
    self.credential = credential
  }

  /// The request for one dictation. A saved `EchoType` in any case is dropped, since the
  /// built-in term already leads the list.
  public init(settings: Settings, keytermLimit: Int, credential: String?) {
    let builtIn = "EchoType"
    let saved = settings.keyterms.filter { $0.caseInsensitiveCompare(builtIn) != .orderedSame }
    self.init(
      language: settings.language,
      keyterms: Array(([builtIn] + saved).prefix(keytermLimit)),
      credential: credential)
  }
}

/// One live transcription session, driven by `SessionMachine`.
///
/// The session guarantees an adapter:
/// - Audio is 16 kHz mono little-endian Int16 PCM, in the chunks capture produces.
/// - No `send` happens before `.ready`; the session holds earlier audio.
/// - Each `send` is awaited before the next starts. `finish()` is called at most once, after the
///   last `send` has returned, and no `send` follows it.
/// - `finish()` may come before `.ready` when no audio was sent; the adapter must accept it.
/// - `close()` may be called at any time and more than once. `waitForClose()` joins adapter work
///   after it.
///
/// An adapter guarantees the session:
/// - `.ready` arrives once, before any transcript.
/// - Each `.transcript` carries the complete current transcript, not a change.
/// - `.speech` arrives whenever the provider shows evidence that someone is talking.
/// - `.finished` arrives after `finish()` once the tail is resolved, and then `events` ends. A
///   final `.transcript` carrying the resolved tail may come just before it.
/// - Failures throw `ProviderError`. Any other thrown error is treated as a connection failure.
public protocol LiveTranscriber: Sendable {
  /// Read by exactly one consumer, the session.
  var events: AsyncThrowingStream<TranscriptionEvent, any Error> { get }
  func send(audio: Data) async throws
  func finish() async throws
  func close()
  func waitForClose() async
}

public enum TranscriptionEvent: Equatable, Sendable {
  case ready
  case transcript(Transcript)
  case speech
  case finished
}

/// The complete transcript at one moment of a session.
public struct Transcript: Equatable, Sendable {
  /// The only text that may be inserted. It only grows at its end.
  public var committed: String
  /// Settled text of the current utterance, shown solid. The provider may replace it.
  public var utterance: String
  /// Text the provider may still rewrite, shown dimmed and never inserted.
  public var provisional: String

  public init(committed: String = "", utterance: String = "", provisional: String = "") {
    self.committed = committed
    self.utterance = utterance
    self.provisional = provisional
  }
}

// MARK: Read aloud

/// Text to speech. `speak` starts one reading; nothing is requested until the stream is created.
public struct VoiceService: Sendable {
  /// A short list chosen by hand. The first is the default.
  public var voices: [Voice]
  /// The speaking rate as a multiplier, where 1 is normal.
  public var speedRange: ClosedRange<Double>
  /// The longest text one reading accepts, counted in Unicode scalars.
  public var maximumCharacters: Int
  public var speak: @Sendable (SpeechRequest) -> any SpeechStream

  public init(
    voices: [Voice], speedRange: ClosedRange<Double>, maximumCharacters: Int,
    speak: @escaping @Sendable (SpeechRequest) -> any SpeechStream
  ) {
    self.voices = voices
    self.speedRange = speedRange
    self.maximumCharacters = maximumCharacters
    self.speak = speak
  }

  /// The text cut to its first `maximumCharacters`. Counts Unicode scalars rather than
  /// `Character`s, so a selection full of multi-scalar emoji still fits a limit the provider
  /// may count in code points.
  public func capped(_ text: String) -> String {
    String(text.unicodeScalars.prefix(maximumCharacters))
  }
}

public struct Voice: Hashable, Identifiable, Sendable {
  /// The provider's own name for the voice, stored in Settings.
  public var id: String
  /// Shown in the Read Aloud tab.
  public var name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}

public struct SpeechRequest: Equatable, Sendable {
  public var text: String
  /// One of the service's voice ids.
  public var voice: String
  /// Within the service's `speedRange`.
  public var speed: Double
  /// BCP-47 language tag.
  public var language: String
  public var credential: String?

  public init(text: String, voice: String, speed: Double, language: String, credential: String?) {
    self.text = text
    self.voice = voice
    self.speed = speed
    self.language = language
    self.credential = credential
  }

  /// The request for one reading of already capped text, with the stored voice, the validated
  /// speed and the dictation language.
  public init(text: String, settings: Settings, credential: String?) {
    self.init(
      text: text, voice: settings.voice, speed: settings.validatedSpeechSpeed,
      language: settings.language, credential: credential)
  }
}

/// One reading's audio, pulled by a single consumer, the reader.
///
/// Pulling is the backpressure: while playback is paused the reader stops calling `next()`, and
/// the adapter must not read ahead from the provider without bound. Every chunk of one stream
/// has the same sample rate and holds at most 100 ms of audio.
public protocol SpeechStream: Sendable {
  /// The next chunk, or nil at the end. Failures throw `ProviderError`; anything else is a
  /// connection or cancellation failure.
  func next() async throws -> SpeechAudio?
  /// Stops the request and makes a pending `next()` throw. The caller stops pulling after
  /// cancelling and must not rely on later results. May be called at any time and more than once.
  func cancel()
}

/// Mono Float32 samples in -1...1.
public struct SpeechAudio: Equatable, Sendable {
  public var sampleRate: Int
  public var samples: [Float]

  public init(sampleRate: Int, samples: [Float]) {
    self.sampleRate = sampleRate
    self.samples = samples
  }
}

// MARK: Cleanup

/// Revises a window of committed dictation. `Reviser` owns the prompt, the windows and the
/// faithfulness check; the service only makes one request and returns the model's reply.
public struct CleanupService: Sendable {
  public var revise: @Sendable (CleanupRequest) async throws -> String

  public init(revise: @escaping @Sendable (CleanupRequest) async throws -> String) {
    self.revise = revise
  }
}

public struct CleanupRequest: Equatable, Sendable {
  /// The instructions, sent as the system message or the provider's equivalent.
  public var prompt: String
  /// The dictated text to revise.
  public var text: String
  /// The last revision before insertion. Someone is waiting, so the adapter should give up
  /// sooner than for a live revision.
  public var final: Bool
  public var credential: String?

  public init(prompt: String, text: String, final: Bool, credential: String?) {
    self.prompt = prompt
    self.text = text
    self.final = final
    self.credential = credential
  }
}
