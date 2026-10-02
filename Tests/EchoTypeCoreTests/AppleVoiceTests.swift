import AVFoundation
@testable import EchoTypeCore
import Foundation
import Testing

@Suite struct AppleVoiceTests {
  // MARK: Utterances

  @Test("An utterance ends at the last complete sentence within the bound")
  func utterancesPreferSentences() {
    let sentence = "Every" + String(repeating: " word", count: 18) + " ends. "  // 102 scalars
    let text = String(repeating: sentence, count: 5)
    var rest = text[...]
    var utterances: [String] = []
    while let (utterance, next) = Apple.Speech.nextUtterance(in: rest) {
      utterances.append(String(utterance))
      rest = next
    }
    #expect(utterances == [sentence + sentence, sentence + sentence, sentence])
  }

  @Test("A sentence longer than the bound splits after a word, or at the bound without one")
  func longSentencesSplit() throws {
    let words = String(repeating: "word ", count: 60)  // 300 scalars, no sentence end
    let (utterance, rest) = try #require(Apple.Speech.nextUtterance(in: words[...]))
    #expect(utterance.unicodeScalars.count == 250)
    #expect(utterance.hasSuffix("word "))
    #expect(rest == String(repeating: "word ", count: 10)[...])

    let unbroken = String(repeating: "x", count: 300)
    let (hard, tail) = try #require(Apple.Speech.nextUtterance(in: unbroken[...]))
    #expect(hard.unicodeScalars.count == 250)
    #expect(tail.unicodeScalars.count == 50)
  }

  @Test("Leading whitespace is skipped and whitespace alone says nothing")
  func whitespaceIsSkipped() throws {
    #expect(Apple.Speech.nextUtterance(in: " \n "[...]) == nil)
    let (utterance, rest) = try #require(Apple.Speech.nextUtterance(in: "  Hello."[...]))
    #expect(utterance == "Hello.")
    #expect(rest.isEmpty)
  }

  // MARK: Audio

  @Test("Audio comes out in chunks of at most 100 ms at one sample rate")
  func chunksAreBounded() throws {
    var chunks = Apple.Speech.Chunks()
    try chunks.append(Array(repeating: 0.5, count: 5000), sampleRate: 22_050)
    try chunks.append(Array(repeating: -0.5, count: 300), sampleRate: 22_050)
    var sizes: [Int] = []
    while let chunk = chunks.next() {
      #expect(chunk.sampleRate == 22_050)
      sizes.append(chunk.samples.count)
    }
    #expect(sizes == [2205, 2205, 890])
    #expect(throws: ProviderError.self) { try chunks.append([0], sampleRate: 24_000) }
  }

  @Test("Buffers become mono Float32 by averaging their channels")
  func buffersBecomeMono() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2))
    buffer.frameLength = 2
    let channels = try #require(buffer.floatChannelData)
    (channels[0][0], channels[0][1]) = (1, 0.5)
    (channels[1][0], channels[1][1]) = (0, -0.5)
    #expect(Apple.Speech.samples(from: buffer) == [0.5, 0])
  }

  // MARK: Speed

  @Test("1x is the default rate for every voice, and the range includes it")
  func normalSpeedIsDefaultRate() {
    #expect(Apple.Speech.speedRange.contains(1))
    for voice in Apple.Speech.voices.map(\.id) + ["com.apple.voice.enhanced.en-GB.Daniel"] {
      #expect(Apple.Speech.rate(speed: 1, voice: voice) == AVSpeechUtteranceDefaultSpeechRate)
    }
    let zoe = Apple.Speech.voices[0].id
    #expect(abs(Apple.Speech.rate(speed: 1.25, voice: zoe) - 0.5414) < 0.0001)
    #expect(abs(Apple.Speech.rate(speed: 1.125, voice: zoe) - 0.5207) < 0.0001)
  }

  // MARK: Voices

  private let zoe = Apple.Speech.InstalledVoice(id: "com.apple.voice.premium.en-US.Zoe", language: "en-US", quality: .premium)
  private let jamie = Apple.Speech.InstalledVoice(id: "com.apple.voice.premium.en-GB.Malcolm", language: "en-GB", quality: .premium)
  private let daniel = Apple.Speech.InstalledVoice(id: "com.apple.voice.enhanced.en-GB.Daniel", language: "en-GB", quality: .enhanced)
  private let albert = Apple.Speech.InstalledVoice(id: "com.apple.speech.synthesis.voice.Albert", language: "en-US", quality: .default)
  private let samantha = Apple.Speech.InstalledVoice(id: "com.apple.voice.compact.en-US.Samantha", language: "en-US", quality: .default)
  private let thomas = Apple.Speech.InstalledVoice(id: "com.apple.voice.compact.fr-FR.Thomas", language: "fr-FR", quality: .default)

  @Test("The saved voice is used when it is installed and speaks the language")
  func savedVoiceIsUsed() {
    #expect(Apple.Speech.resolve(jamie.id, language: "en", among: [zoe, jamie]) == jamie.id)
    #expect(Apple.Speech.resolve(jamie.id, language: "en-US", among: [zoe, jamie]) == jamie.id)
  }

  @Test("Fallback picks an installed voice for the language and the saved choice comes back")
  func fallbackKeepsSavedChoice() {
    let saved = zoe.id
    // Offered voices first, then by quality, then Apple's natural voices.
    #expect(Apple.Speech.resolve(saved, language: "en", among: [daniel, jamie, albert]) == jamie.id)
    #expect(Apple.Speech.resolve(saved, language: "en", among: [samantha, daniel, albert]) == daniel.id)
    #expect(Apple.Speech.resolve(saved, language: "en", among: [albert, samantha]) == samantha.id)
    #expect(Apple.Speech.resolve(saved, language: "fr", among: [zoe, thomas]) == thomas.id)
    // Nothing was written over the saved id, so installing it again restores it.
    #expect(Apple.Speech.resolve(saved, language: "en", among: [daniel, zoe]) == saved)
  }

  @Test("No installed voice for the language is unavailable with download guidance")
  func noVoiceIsUnavailable() {
    #expect(
      Apple.Speech.check(language: "de", voice: zoe.id, installed: [zoe, thomas])
        == .unavailable("Download a voice in System Settings > Accessibility > Read & Speak"))
    #expect(Apple.Speech.check(language: "en", voice: jamie.id, installed: [zoe]) == .ready)
  }
}
