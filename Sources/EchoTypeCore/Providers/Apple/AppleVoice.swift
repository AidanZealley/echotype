import AVFoundation
import Foundation

extension Apple {
  /// Read aloud through `AVSpeechSynthesizer`, rendered to PCM rather than played.
  static let voice = VoiceService(
    voices: Speech.voices, speedRange: Speech.speedRange,
    maximumCharacters: Speech.maximumCharacters
  ) { request in
    Speech.Stream(
      text: request.text,
      voice: Speech.resolve(
        request.voice, language: request.language, among: Speech.installedVoices(),
        systemDefault: Speech.systemDefaultVoice(for: request.language)),
      speed: request.speed)
  }

  enum Speech {
    /// The saved choice that follows the system's default voice for the language.
    static let systemVoiceID = "system"
    static let zoeID = "com.apple.voice.premium.en-US.Zoe"
    /// Siri voices are not available through this API. Jamie is the framework's Malcolm.
    static let voices = [
      Voice(id: systemVoiceID, name: "System voice"),
      Voice(id: zoeID, name: "Zoe"),
      Voice(id: "com.apple.voice.premium.en-GB.Malcolm", name: "Jamie"),
    ]
    /// Accepted by ear for Zoe and Jamie.
    static let speedRange = 0.8...1.3
    static let maximumCharacters = 60_000
    /// The most text one utterance holds. Synthesis cannot be paused, so the next utterance
    /// starts only once the last one's audio is pulled; this bounds what a paused reading holds.
    static let utteranceLimit = 250
    static let missingVoice =
      "No voice is downloaded for this language. Download one in Accessibility > Read & Speak."

    // MARK: Voices

    /// The parts of an installed voice that resolution looks at.
    struct InstalledVoice: Equatable {
      var id: String
      /// BCP-47, such as `en-GB`.
      var language: String
    }

    static func installedVoices() -> [InstalledVoice] {
      AVSpeechSynthesisVoice.speechVoices().map { InstalledVoice(id: $0.identifier, language: $0.language) }
    }

    /// The voice the system reads the language with, if it has one.
    static func systemDefaultVoice(for language: String) -> InstalledVoice? {
      AVSpeechSynthesisVoice(language: Apple.locale(for: language).identifier(.bcp47))
        .map { InstalledVoice(id: $0.identifier, language: $0.language) }
    }

    /// Voice readiness, which needs only a voice for the language. The system voice standing in
    /// for a named one is ready, with a note saying so. Downloading the named voice is up to the
    /// user; `Apple.changes` yields when the installed voices change.
    static func check(language: String, voice: String) -> ServiceState {
      check(
        language: language, voice: voice, installed: installedVoices(),
        systemDefault: systemDefaultVoice(for: language))
    }

    static func check(
      language: String, voice: String, installed: [InstalledVoice], systemDefault: InstalledVoice?
    ) -> ServiceState {
      guard let used = resolve(voice, language: language, among: installed, systemDefault: systemDefault) else {
        return .unavailable(missingVoice, fix: SystemSettings.readAndSpeak)
      }
      guard used != voice, let named = voices.first(where: { $0.id == voice && $0.id != systemVoiceID })
      else { return .ready }
      if installed.contains(where: { $0.id == voice }) {
        return .ready("\(named.name) doesn't speak this language, so the system voice reads instead.")
      }
      return .ready(
        "\(named.name) isn't downloaded, so the system voice reads instead. Download \(named.name) in Accessibility > Read & Speak.",
        fix: SystemSettings.readAndSpeak)
    }

    /// The saved voice when it is a named voice that is installed and speaks the language,
    /// otherwise the system's default voice for the language, otherwise nil. The saved choice is
    /// left as it is, so it comes back once it is installed or suits the language again.
    static func resolve(
      _ saved: String, language: String, among installed: [InstalledVoice], systemDefault: InstalledVoice?
    ) -> String? {
      let code = Locale.Language(identifier: language).languageCode
      func speaks(_ voice: InstalledVoice) -> Bool { Locale.Language(identifier: voice.language).languageCode == code }
      if saved != systemVoiceID, installed.contains(where: { $0.id == saved && speaks($0) }) { return saved }
      return systemDefault.flatMap { speaks($0) ? $0.id : nil }
    }

    // MARK: Speed

    /// The speeds each voice's anchors are measured at.
    private static let anchorSpeeds = [0.7, 0.85, 1, 1.25, 1.5]
    /// `AVSpeechUtterance.rate` values that make each voice speak at `anchorSpeeds`. Measured
    /// silently by rendering one sentence over a grid of rates and interpolating where its
    /// duration, relative to the default rate's, meets each speed. A voice without its own
    /// anchors, including the system voice and whichever voice it resolves to, uses Zoe's.
    private static let anchorRates: [String: [Double]] = [
      zoeID: [0.1626, 0.3426, 0.5, 0.5414, 0.5849],
      "com.apple.voice.premium.en-GB.Malcolm": [0.1571, 0.3259, 0.5, 0.5418, 0.5837],
    ]

    /// The utterance rate for a speed multiplier, interpolated between the voice's anchors.
    static func rate(speed: Double, voice: String) -> Float {
      let rates = anchorRates[voice] ?? anchorRates[zoeID]!
      let speeds = anchorSpeeds
      let value = min(max(speed, speeds[0]), speeds[speeds.count - 1])
      let upper = speeds.indices.dropFirst().first { value <= speeds[$0] }!
      let fraction = (value - speeds[upper - 1]) / (speeds[upper] - speeds[upper - 1])
      return Float(rates[upper - 1] + fraction * (rates[upper] - rates[upper - 1]))
    }

    // MARK: Text

    /// The next utterance and the text after it, skipping leading whitespace; nil when nothing
    /// is left to say. An utterance prefers to end at the last complete sentence within
    /// `utteranceLimit` scalars, then after the last space, then at the limit itself.
    static func nextUtterance(in text: Substring) -> (utterance: Substring, rest: Substring)? {
      let text = text.drop { $0.isWhitespace }
      guard !text.isEmpty else { return nil }
      let scalars = text.unicodeScalars
      guard let bound = scalars.index(scalars.startIndex, offsetBy: utteranceLimit, limitedBy: scalars.endIndex),
        bound != scalars.endIndex
      else { return (text, text[text.endIndex...]) }
      var end: String.Index?
      text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { _, _, sentence, stop in
        if sentence.upperBound <= bound { end = sentence.upperBound } else { stop = true }
      }
      if end == nil, let space = scalars[..<bound].lastIndex(where: { $0.properties.isWhitespace }) {
        end = scalars.index(after: space)
      }
      let split = end ?? bound
      return (text[..<split], text[split...])
    }

    // MARK: Audio

    /// The buffer's frames as mono Float32, averaging any channels; nil for a format other than
    /// Float32.
    static func samples(from buffer: AVAudioPCMBuffer) -> [Float]? {
      guard let data = buffer.floatChannelData else { return nil }
      let frames = Int(buffer.frameLength)
      let channels = Int(buffer.format.channelCount)
      let interleaved = buffer.format.isInterleaved
      return (0..<frames).map { frame in
        (0..<channels).reduce(Float(0)) { sum, channel in
          sum + (interleaved ? data[0][frame * channels + channel] : data[channel][frame])
        } / Float(channels)
      }
    }

    /// Rendered samples waiting to be pulled, handed out in chunks of at most 100 ms.
    struct Chunks {
      private var sampleRate: Int?
      private var samples: [Float] = []
      private var offset = 0

      mutating func append(_ new: [Float], sampleRate rate: Int) throws {
        if let sampleRate, sampleRate != rate { throw ProviderError.failed("The voice changed its sample rate") }
        sampleRate = rate
        if offset == samples.count {
          samples.removeAll(keepingCapacity: true)
          offset = 0
        }
        samples.append(contentsOf: new)
      }

      mutating func next() -> SpeechAudio? {
        guard let sampleRate, offset < samples.count else { return nil }
        let end = min(offset + sampleRate / 10, samples.count)
        defer { offset = end }
        return SpeechAudio(sampleRate: sampleRate, samples: Array(samples[offset..<end]))
      }

      mutating func removeAll() {
        samples = []
        offset = 0
      }
    }

    // MARK: Stream

    /// One reading. It renders one utterance at a time and starts the next only when the
    /// caller has pulled all of the last one's audio, so a paused reader stops synthesis.
    ///
    /// The synthesiser's buffers and its finish arrive on its own thread and are handed to the
    /// main actor in order, so an utterance ends only after its last buffer is queued. A
    /// zero-frame buffer can arrive mid-utterance, so only `didFinish` ends one.
    @MainActor
    final class Stream: NSObject, SpeechStream, AVSpeechSynthesizerDelegate {
      private let voice: String?
      private let speed: Double
      /// The text not yet given to the synthesiser.
      private(set) var remaining: Substring
      private var chunks = Chunks()
      /// Created with the first utterance, on the main actor.
      private var synthesizer: AVSpeechSynthesizer?
      private var speaking = false
      /// Cancellation or a failure, which every later pull throws.
      private var ending: (any Error)?
      private var waiter: CheckedContinuation<SpeechAudio?, any Error>?

      /// `voice` is the resolved voice id, or nil when there is none for the language.
      nonisolated init(text: String, voice: String?, speed: Double) {
        self.voice = voice
        self.speed = speed
        remaining = text[...]
      }

      func next() async throws -> SpeechAudio? {
        try await withTaskCancellationHandler {
          try Task.checkCancellation()
          return try await withCheckedThrowingContinuation { continuation in
            precondition(waiter == nil, "SpeechStream has one consumer")
            waiter = continuation
            deliver()
          }
        } onCancel: { cancel() }
      }

      nonisolated func cancel() {
        Task { @MainActor in end(CancellationError()) }
      }

      nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
          guard let self, ending == nil else { return }
          speaking = false
          deliver()
        }
      }

      private func deliver() {
        guard let waiter else { return }
        if let ending {
          self.waiter = nil
          waiter.resume(throwing: ending)
        } else if let chunk = chunks.next() {
          self.waiter = nil
          waiter.resume(returning: chunk)
        } else if !speaking {
          if let (utterance, rest) = nextUtterance(in: remaining) {
            remaining = rest
            speak(utterance)
          } else {
            self.waiter = nil
            waiter.resume(returning: nil)
          }
        }
      }

      private func speak(_ text: Substring) {
        guard let voice, let synthesisVoice = AVSpeechSynthesisVoice(identifier: voice) else {
          return end(ProviderError.failed(missingVoice))
        }
        let utterance = AVSpeechUtterance(string: String(text))
        utterance.voice = synthesisVoice
        utterance.rate = rate(speed: speed, voice: voice)
        let synthesizer = synthesizer ?? AVSpeechSynthesizer()
        synthesizer.delegate = self
        self.synthesizer = synthesizer
        speaking = true
        synthesizer.write(utterance) { [weak self] buffer in
          guard let buffer = buffer as? AVAudioPCMBuffer else { return }
          let samples = Speech.samples(from: buffer)
          let sampleRate = Int(buffer.format.sampleRate)
          DispatchQueue.main.async { [weak self] in
            self?.received(samples, sampleRate: sampleRate)
          }
        }
      }

      private func received(_ samples: [Float]?, sampleRate: Int) {
        guard ending == nil else { return }
        do {
          guard let samples else { throw ProviderError.failed("The voice produced an unsupported audio format") }
          if !samples.isEmpty { try chunks.append(samples, sampleRate: sampleRate) }
          deliver()
        } catch { end(error) }
      }

      /// Stops synthesis and makes this and every later pull throw `error`.
      private func end(_ error: any Error) {
        guard ending == nil else { return }
        ending = error
        remaining = ""
        chunks.removeAll()
        synthesizer?.stopSpeaking(at: .immediate)
        deliver()
      }
    }
  }
}
