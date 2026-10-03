@testable import EchoTypeCore
import Foundation
import Testing

/// Real `AVSpeechSynthesizer` readings, rendered to PCM and never played. Skipped unless
/// `ECHOTYPE_APPLE_LIVE=1`, so an ordinary run touches no synthesiser:
///
/// ```bash
/// ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleVoice
/// ```
///
/// Zoe Premium and Jamie Premium must be installed in System Settings > Accessibility > Read &
/// Speak.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_LIVE"] == "1", "Set ECHOTYPE_APPLE_LIVE=1."))
@MainActor
struct AppleVoiceLiveTests {
  private let paragraph = """
    EchoType reads this paragraph on the Mac. A steady voice should carry the meaning across each sentence, with natural pauses and clear pronunciation. When a reader pauses for a moment, the next words should still make sense. We are comparing the rhythm around a segment boundary inside this longer sentence, where a small break might sound awkward even though every word is present. At the end, listen for whether the final sentence sounds complete.
    """

  @Test("Each voice reads a paragraph to the end as bounded mono Float32", arguments: Apple.Speech.voices)
  func voiceReadsToTheEnd(voice: Voice) async throws {
    #expect(Apple.Speech.check(language: "en", voice: voice.id) == .ready)
    let stream = Apple.voice.speak(SpeechRequest(text: paragraph, voice: voice.id, speed: 1, language: "en", credential: nil))
    var sampleRate: Int?
    var samples = 0
    while let chunk = try await stream.next() {
      sampleRate = sampleRate ?? chunk.sampleRate
      #expect(chunk.sampleRate == sampleRate)
      #expect(!chunk.samples.isEmpty && chunk.samples.count <= chunk.sampleRate / 10)
      #expect(chunk.samples.allSatisfy { $0.isFinite && (-1...1).contains($0) })
      samples += chunk.samples.count
    }
    // The research measured about 24 s for this paragraph; a reading cut at its first
    // utterance would be about half that.
    let seconds = Double(samples) / Double(try #require(sampleRate))
    #expect(seconds > 18 && seconds < 35, "\(seconds) s")
  }

  @Test("A paused reading submits nothing more, then resumes through the paragraph")
  func pausedReadingStopsSubmitting() async throws {
    let stream = reading(paragraph)
    defer { stream.cancel() }
    let first = try #require(try await stream.next())
    let remaining = stream.remaining
    #expect(paragraph.unicodeScalars.count - remaining.unicodeScalars.count <= Apple.Speech.utteranceLimit)
    try await Task.sleep(for: .seconds(2))
    #expect(stream.remaining == remaining)
    var samples = first.samples.count
    while let chunk = try await stream.next() { samples += chunk.samples.count }
    let seconds = Double(samples) / Double(first.sampleRate)
    // The same complete paragraph bound used by voiceReadsToTheEnd, excluding the pause.
    #expect(seconds > 18 && seconds < 35, "\(seconds) s after resuming")
  }

  @Test("Cancelling a pending pull throws promptly, and another reading then works")
  func cancelEndsPendingPull() async throws {
    let stream = reading(paragraph)
    let pull = Task { try await stream.next() }
    // Synthesis takes several hundred milliseconds to produce its first buffer.
    try await Task.sleep(for: .milliseconds(20))
    let started = ContinuousClock.now
    stream.cancel()
    stream.cancel()
    await #expect(throws: CancellationError.self) { try await pull.value }
    #expect(ContinuousClock.now - started < .milliseconds(100))

    let next = reading("This reading still works.")
    var samples = 0
    while let chunk = try await next.next() { samples += chunk.samples.count }
    #expect(samples > 0)
  }

  @Test("A missing saved voice reads using a real installed English fallback")
  func missingVoiceReadsWithFallback() async throws {
    let saved = "echotype.test.missing-voice"
    let fallback = try #require(Apple.Speech.resolve(saved, language: "en", among: Apple.Speech.installedVoices()))
    #expect(fallback != saved)
    #expect(Apple.Speech.check(language: "en", voice: saved) == .ready)
    let stream = Apple.voice.speak(SpeechRequest(
      text: "The installed fallback voice still reads this sentence.", voice: saved, speed: 1,
      language: "en", credential: nil))
    defer { stream.cancel() }
    var samples = 0
    while let chunk = try await stream.next() { samples += chunk.samples.count }
    #expect(samples > 0)
    print("Apple fallback voice: \(fallback)")
  }

  private func reading(_ text: String) -> Apple.Speech.Stream {
    Apple.Speech.Stream(text: text, voice: Apple.Speech.voices[0].id, speed: 1)
  }
}
