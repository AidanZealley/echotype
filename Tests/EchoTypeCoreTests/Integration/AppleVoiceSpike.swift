import AVFoundation
import Foundation
import FoundationModels
import Testing
@testable import EchoTypeCore

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_SPIKE"] == "1",
  "Set ECHOTYPE_APPLE_SPIKE=1; synthesis is silent and no service starts otherwise."))
@MainActor
struct AppleVoiceSpike {
  private let sentence = "EchoType reads this sentence on the Mac. We can pause the reading and continue without losing any words."

  @Test func inventoryAppleVoiceSpike() throws {
    print("OS \(ProcessInfo.processInfo.operatingSystemVersionString); intelligence \(SystemLanguageModel.default.availability)")
    print("rates min=\(AVSpeechUtteranceMinimumSpeechRate) default=\(AVSpeechUtteranceDefaultSpeechRate) max=\(AVSpeechUtteranceMaximumSpeechRate)")
    let voices = AVSpeechSynthesisVoice.speechVoices()
    for voice in voices.sorted(by: { $0.identifier < $1.identifier }) {
      print("VOICE \(voice.identifier) | \(voice.name) | \(voice.language) | quality=\(voice.quality.rawValue) | \(voice.audioFileSettings)")
    }
    print("Voice count \(voices.count); Zoe advertised \(voices.filter { $0.name.localizedCaseInsensitiveContains("Zoe") }.map(\.identifier))")
    print("Siri advertised \(voices.filter { $0.identifier.lowercased().contains("siri") }.map(\.identifier))")
    for identifier in ["com.apple.voice.super-compact.en-US.Samantha", "com.apple.ttsbundle.siri_female_en-US_compact", "com.apple.voice.premium.en-US.Zoe", "invalid.missing.voice"] {
      print("lookup \(identifier): \(AVSpeechSynthesisVoice(identifier: identifier)?.identifier ?? "nil")")
    }
    for tag in ["en", "en-GB", "en-US", "fr", "de", "ja", "zh-Hant", "xx-ZZ"] {
      let selected = resolve(saved: "invalid.missing.voice", language: tag)
      print("fallback \(tag): \(selected?.identifier ?? "unavailable"); saved id remains invalid.missing.voice")
    }
    #expect(AVSpeechSynthesisVoice(identifier: "invalid.missing.voice") == nil)
    #expect(resolve(saved: "invalid.missing.voice", language: "xx-ZZ") == nil)
  }

  @Test func buffersAndRatesAppleVoiceSpike() async throws {
    let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" || $0.language == "en-GB" }
    let selected = voices.filter { $0.quality != .default || $0.identifier.lowercased().contains("siri") }
    // Sample every advertised premium/enhanced English voice, or the system default if absent.
    let candidates = selected.isEmpty ? [try #require(resolve(saved: "", language: "en"))] : selected
    for voice in candidates {
      let result = try await measure(text: sentence, voice: voice, speed: 1)
      print("VOICE RESULT \(voice.identifier) \(result)")
    }
  }

  @Test func listeningComparisonsAppleVoiceSpike() async throws {
    let candidates = comparisonVoices
    print("COMPARISON Zoe Premium available=\(candidates.contains { $0.quality == .premium && $0.name.localizedCaseInsensitiveContains("Zoe") }); no missing voice is substituted")
    #expect(candidates.count == 3)
    for voice in candidates {
      for segmented in [false, true] {
        let label = segmented ? "paragraph-sentence-aware" : "paragraph-continuous"
        let result = try await measure(text: paragraph, voice: voice, speed: 1,
          rate: AVSpeechUtteranceDefaultSpeechRate, sampleName: label,
          segmentLimit: segmented ? AppleSpikeSpeechStream.segmentCharacters : paragraph.unicodeScalars.count)
        print("COMPARISON \(voice.identifier) \(label) scalars=\(paragraph.unicodeScalars.count) \(result)")
      }
    }
  }

  @Test func calibrationAppleVoiceSpike() async throws {
    for voice in comparisonVoices {
      for speed in [0.7, 0.85, 0.925, 1, 1.1, 1.25, 1.4, 1.5] {
        print("MAPPED_RATE voice=\(voice.identifier) speed=\(speed) avRate=\(mappedRate(speed, voice: voice)) \(try await measure(text: sentence, voice: voice, speed: speed))")
      }
      for speed in [0.7, 1, 1.5] {
        print("PARAGRAPH_RATE voice=\(voice.identifier) speed=\(speed) avRate=\(mappedRate(speed, voice: voice)) \(try await measure(text: paragraph, voice: voice, speed: speed, sampleName: "paragraph-speed-\(speed)", segmentLimit: paragraph.unicodeScalars.count))")
      }
    }
  }

  @Test func languageFallbackAppleVoiceSpike() async throws {
    let saved = "com.apple.voice.enhanced.en-GB.Daniel"
    #expect(resolve(saved: saved, language: "en")?.identifier == saved)
    for (language, text) in [("en-US", sentence), ("fr-FR", "Bonjour. Cette lecture fonctionne sur le Mac."), ("zh-Hant", "這是語音合成測試。") ] {
      let voice = try #require(resolve(saved: saved, language: language))
      #expect((voice.identifier == saved) == (language == "en-US"))
      print("LANGUAGE saved=\(saved) requested=\(language) resolved=\(voice.identifier) \(try await measure(text: text, voice: voice, speed: 1))")
    }
  }

  @Test func lifecycleAppleVoiceSpike() async throws {
    let voice = try #require(resolve(saved: "", language: "en-GB"))
    let text = String(repeating: sentence + " ", count: 12)
    let stream = AppleSpikeSpeechStream(text: text, voice: voice, rate: mappedRate(1, voice: voice))
    let deadline = watchdog(stream)
    defer { deadline.cancel(); stream.cancel() }
    print("MEMORY beforeFirstPull rssKiB=\(try residentKilobytes())")
    let first = try #require(try await stream.next())
    validate(first, sampleRate: stream.sampleRate)
    try await Task.sleep(for: .seconds(2))
    print("MEMORY pause2s rssKiB=\(try residentKilobytes())")
    let pausedCallbacks = stream.callbacks
    let pausedSamples = stream.totalSamples
    print("PAUSE after2s segments=\(stream.segments) segmentScalars=\(stream.segmentScalars) segmentSamples=\(stream.segmentSamples) submittedRates=\(stream.submittedRates) zeroFrameSampleOffsets=\(stream.zeroFrameSampleOffsets) callbacks=\(pausedCallbacks) totalSamples=\(pausedSamples) peak=\(stream.peakSamples)")
    try await Task.sleep(for: .seconds(2))
    print("MEMORY pause4s rssKiB=\(try residentKilobytes())")
    #expect(stream.callbacks == pausedCallbacks)
    #expect(stream.totalSamples == pausedSamples)
    #expect(stream.segments == 1)
    var pulled = first.samples.count
    var chunks = 1
    while let chunk = try await stream.next() {
      validate(chunk, sampleRate: first.sampleRate)
      pulled += chunk.samples.count
      chunks += 1
    }
    print("MEMORY drained rssKiB=\(try residentKilobytes())")
    #expect(pulled == stream.totalSamples)
    #expect(stream.submittedScalars == text.unicodeScalars.count)
    print("RESUME chars=\(text.unicodeScalars.count) pulled=\(pulled) generated=\(stream.totalSamples) chunks=\(chunks) segments=\(stream.segments) peakSamples=\(stream.peakSamples) peakRetainedBytes=\(stream.peakRetainedSamples * 4)")

    // Begin a real synthesis pull and cancel before the first callback can complete.
    let pending = AppleSpikeSpeechStream(text: text, voice: voice, rate: mappedRate(1, voice: voice))
    let pull = Task { try await pending.next() }
    await Task.yield()
    #expect(pending.hasPendingPull)
    let cancelStart = ProcessInfo.processInfo.systemUptime
    pending.cancel()
    pending.cancel()
    do { _ = try await pull.value; Issue.record("Pending next did not throw on cancellation") }
    catch is CancellationError {}
    print("CANCEL pending pull ms=\((ProcessInfo.processInfo.systemUptime - cancelStart) * 1000) segments=\(pending.segments)")
    let callbackCount = pending.callbacks
    try await Task.sleep(for: .milliseconds(200))
    #expect(pending.callbacks == callbackCount)
    #expect(!pending.isSynthesizing)
    print("RESTART \(try await measure(text: sentence, voice: voice, speed: 1))")

    let large = AppleSpikeSpeechStream(text: String(repeating: "word ", count: 12_000), voice: voice, rate: mappedRate(1, voice: voice))
    let largeDeadline = watchdog(large)
    defer { largeDeadline.cancel(); large.cancel() }
    _ = try await large.next()
    large.cancel()
    print("TEXT LIMIT proposed=60000 scalars; first pull accepted, only \(large.segments) bounded segment submitted; full 60000-scalar completion unmeasured")
  }

  private let paragraph = """
      EchoType reads this paragraph on the Mac. A steady voice should carry the meaning across each sentence, with natural pauses and clear pronunciation. When a reader pauses for a moment, the next words should still make sense. We are comparing the rhythm around a segment boundary inside this longer sentence, where a small break might sound awkward even though every word is present. At the end, listen for whether the final sentence sounds complete.
      """

  private var comparisonVoices: [AVSpeechSynthesisVoice] {
    let ids = ["com.apple.voice.enhanced.en-GB.Daniel", "com.apple.voice.compact.en-US.Samantha", "com.apple.voice.premium.en-US.Zoe"]
    return ids.compactMap { AVSpeechSynthesisVoice(identifier: $0) }
  }

  private func residentKilobytes() throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-o", "rss=", "-p", String(ProcessInfo.processInfo.processIdentifier)]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func resolve(saved: String, language: String) -> AVSpeechSynthesisVoice? {
    let locale = Locale(identifier: language)
    let code = locale.language.languageCode?.identifier
    let script = locale.language.script?.identifier
    let suitable = AVSpeechSynthesisVoice.speechVoices().filter {
      let candidate = Locale(identifier: $0.language)
      return candidate.language.languageCode?.identifier == code &&
        (script == nil || candidate.language.script?.identifier == script)
    }.sorted {
      let leftExact = $0.language.caseInsensitiveCompare(language) == .orderedSame
      let rightExact = $1.language.caseInsensitiveCompare(language) == .orderedSame
      if leftExact != rightExact { return leftExact }
      if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
      let leftNatural = $0.identifier.hasPrefix("com.apple.voice.")
      let rightNatural = $1.identifier.hasPrefix("com.apple.voice.")
      if leftNatural != rightNatural { return leftNatural }
      return $0.identifier < $1.identifier
    }
    return suitable.first(where: { $0.identifier == saved }) ?? suitable.first
  }

  private func mappedRate(_ speed: Double, voice: AVSpeechSynthesisVoice) -> Float {
    // Fixed calibration anchors from the 104-scalar sentence grid on this Mac. These
    // explore duration control, not a usable range; Aidan rejected the offered extremes.
    // Samantha's 0.15 is its nearest measured 0.7x anchor because slow rates are quantized.
    let rates: [Double]
    switch voice.identifier {
    case "com.apple.voice.compact.en-US.Samantha": rates = [0.15, 0.3216, 0.5, 0.5427, 0.5894]
    case "com.apple.voice.premium.en-US.Zoe": rates = [0.1626, 0.3426, 0.5, 0.5414, 0.5849]
    default: rates = [0.1578, 0.3297, 0.5, 0.542, 0.586] // Daniel; other voices are sampled only at 1x.
    }
    let speeds = [0.7, 0.85, 1, 1.25, 1.5]
    let value = min(max(speed, speeds[0]), speeds[4])
    let upper = speeds.indices.dropFirst().first { value <= speeds[$0] } ?? 4
    let lower = upper - 1
    let fraction = (value - speeds[lower]) / (speeds[upper] - speeds[lower])
    return Float(rates[lower] + fraction * (rates[upper] - rates[lower]))
  }

  private func watchdog(_ stream: AppleSpikeSpeechStream) -> Task<Void, Never> {
    Task { @MainActor in
      do { try await Task.sleep(for: .seconds(30)); stream.cancel() }
      catch {}
    }
  }

  private func measure(text: String, voice: AVSpeechSynthesisVoice, speed: Double, rate: Float? = nil, sampleName: String? = nil,
    segmentLimit: Int = AppleSpikeSpeechStream.segmentCharacters) async throws -> String {
    let stream = AppleSpikeSpeechStream(text: text, voice: voice, rate: rate ?? mappedRate(speed, voice: voice), segmentLimit: segmentLimit)
    let deadline = watchdog(stream)
    defer { deadline.cancel(); stream.cancel() }
    let started = ProcessInfo.processInfo.systemUptime
    var count = 0
    var output: AVAudioFile?
    let outputDirectory = ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_VOICE_SAMPLE_DIR"]
    while let chunk = try await stream.next() {
      validate(chunk, sampleRate: stream.sampleRate)
      count += chunk.samples.count
      if let outputDirectory {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: Double(chunk.sampleRate), channels: 1))
        if output == nil {
          let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let url = directory.appendingPathComponent("\(voice.identifier)-\(sampleName.map { $0 + "-" } ?? "")rate-\(rate ?? mappedRate(speed, voice: voice)).wav")
          output = try AVAudioFile(forWriting: url, settings: format.settings)
          print("SAMPLE \(url.path)")
        }
        let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk.samples.count)))
        pcm.frameLength = pcm.frameCapacity
        let destination = try #require(pcm.floatChannelData?[0])
        chunk.samples.withUnsafeBufferPointer { samples in
          if let base = samples.baseAddress { destination.update(from: base, count: samples.count) }
        }
        try output?.write(from: pcm)
      }
    }
    #expect(count > 0)
    if sampleName != nil {
      // EOF must include PCM following intermediate empty callbacks, with no late tail.
      try await Task.sleep(for: .milliseconds(100))
    }
    #expect(count == stream.totalSamples)
    #expect(stream.submittedScalars == text.unicodeScalars.count)
    #expect(stream.segmentSamples.count == stream.segments)
    #expect(stream.segmentScalars.allSatisfy { $0 <= segmentLimit })
    return "first=\(stream.firstBufferSeconds ?? -1)s duration=\(Double(count) / Double(stream.sampleRate))s wall=\(ProcessInfo.processInfo.systemUptime - started)s sampleRate=\(stream.sampleRate) segments=\(stream.segments) segmentScalars=\(stream.segmentScalars) segmentSamples=\(stream.segmentSamples) submittedRates=\(stream.submittedRates) zeroFrameSampleOffsets=\(stream.zeroFrameSampleOffsets) callbacks=\(stream.callbacks) maxCallback=\(stream.maximumCallbackFrames) formats=\(stream.formats.sorted()) callbackMain=\(stream.callbackOnMain)"
  }

  private func validate(_ chunk: SpeechAudio, sampleRate: Int) {
    #expect(chunk.sampleRate == sampleRate)
    #expect(chunk.samples.count <= sampleRate / 10)
    #expect(!chunk.samples.isEmpty)
    #expect(chunk.samples.allSatisfy { $0.isFinite && (-1...1).contains($0) })
  }
}
