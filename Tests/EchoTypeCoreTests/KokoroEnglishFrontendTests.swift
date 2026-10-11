import Foundation
import Testing

@testable import EchoTypeCore

@Suite struct KokoroEnglishFrontendTests {
  @Test("Pronunciation data is compiled, bundled and separate from model storage")
  func bundledResources() throws {
    let root = try KokoroEnglishFrontend.resourceRoot()
    #expect(!root.path.hasPrefix(ModelStore.defaultRoot.path))
    #expect(FileManager.default.fileExists(atPath: root.appending(path: "COPYING.txt").path))
    #expect(!FileManager.default.fileExists(atPath: root.appending(path: "phsource").path))
    #expect(!FileManager.default.fileExists(atPath: root.appending(path: "dictsource").path))
    #expect(!KokoroManifests.english.files.contains {
      $0.path.hasPrefix("G2P") || $0.path == "g2p_vocab.json" || $0.path == "us_lexicon_cache.json"
    })
  }

  @Test("Missing speech files fail before dependency downloads or cache links")
  func missingModels() async throws {
    let missing = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    await #expect(throws: ProviderError.self) { try await KokoroModel.load(from: missing) }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
  }

  @Test("A conflicting repository path is preserved and rejected before FluidAudio",
    arguments: ["folder", "valid", "dangling"])
  func conflictingRepository(kind: String) async throws {
    let files = FileManager.default
    let root = files.temporaryDirectory.appending(path: UUID().uuidString)
    try files.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? files.removeItem(at: root) }
    // Existence satisfies the outer guard, but these cannot load as models. An exact
    // conflict error proves rejection before voice conversion or FluidAudio's downloader.
    for file in KokoroManifests.english.files {
      let path = root.appending(path: file.path)
      try files.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data().write(to: path)
    }
    let repository = root.appending(path: "kokoro-82m-coreml")
    let foreign = root.appending(path: "foreign")
    if kind == "folder" {
      try files.createDirectory(at: repository, withIntermediateDirectories: true)
    } else {
      if kind == "valid" { try files.createDirectory(at: foreign, withIntermediateDirectories: true) }
      try files.createSymbolicLink(atPath: repository.path, withDestinationPath: "foreign")
    }
    let sentinel = repository.appending(path: "preserve.txt")
    let contents = Data("Unrelated existing directory".utf8)
    if kind != "dangling" { try contents.write(to: sentinel) }
    await #expect(throws: ProviderError.failed(
      "The speech model folder contains a conflicting kokoro-82m-coreml directory. Resolve that folder conflict before preparing speech."
    )) { try await KokoroModel.load(from: root) }
    if kind == "folder" {
      #expect(try files.attributesOfItem(atPath: repository.path)[.type] as? FileAttributeType == .typeDirectory)
    } else {
      #expect(try files.destinationOfSymbolicLink(atPath: repository.path) == "foreign")
    }
    if kind != "dangling" {
      #expect(try Data(contentsOf: sentinel) == contents)
      #expect(try files.contentsOfDirectory(atPath: repository.path) == ["preserve.txt"])
    }
    #expect(!files.fileExists(atPath: root.appending(path: "ANE/bf_emma.bin").path))
  }

  @Test("Minimal installed speech assets synthesize offline with packaged resources",
    .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_KOKORO_OFFLINE_ROOT"] != nil))
  func offlinePackagedSynthesis() async throws {
    let root = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["ECHOTYPE_KOKORO_OFFLINE_ROOT"]))
    let model = try await KokoroModel.load(from: root)
    for voice in KokoroModel.voices {
      let stream = model.speak(SpeechRequest(
        text: "The apple, the hour, the university. I thank thee. At 10:30 a.m., pay $12.50! "
          + String(repeating: "A longer reading keeps each phrase within the model limit. ", count: 12),
        voice: voice.id, speed: 1.2, language: "en", credential: nil))
      var samples = 0
      while let audio = try await stream.next() {
        #expect(audio.sampleRate == 24_000)
        #expect(audio.samples.allSatisfy { $0.isFinite })
        samples += audio.samples.count
      }
      #expect(samples > 24_000)
      print("Packaged offline synthesis succeeded for \(voice.id), \(samples) samples")
    }
  }

  @Test("The article follows spoken vowel context, while literal thee stays strong")
  func articles() async throws {
    let frontend = KokoroEnglishFrontend.shared
    for voice in ["af_heart", "bf_emma"] {
      let apple = try await frontend.phonemes(for: "the apple", voice: voice)
      let hour = try await frontend.phonemes(for: "the hour", voice: voice)
      let banana = try await frontend.phonemes(for: "the banana", voice: voice)
      let university = try await frontend.phonemes(for: "the university", voice: voice)
      let thee = try await frontend.phonemes(for: "I thank thee for the honour.", voice: voice)
      print("\(voice): apple=\(apple); hour=\(hour); banana=\(banana); university=\(university); thee=\(thee)")
      // eSpeak's unstressed pre-vowel article uses short /ɪ/; literal thee uses /iː/.
      #expect(apple.hasPrefix("ðɪ"))
      #expect(hour.hasPrefix("ðɪ"))
      #expect(banana.hasPrefix("ðə"))
      #expect(university.hasPrefix("ðə"))
      #expect(thee.contains("ði"))
    }
  }

  @Test("Long pronunciation output fits the model without losing phonemes")
  func chunking() {
    let phonemes = Array(repeating: "ðə bˈænænə", count: 100).joined(separator: " ")
    let chunks = KokoroEnglishFrontend.chunks(phonemes)
    #expect(chunks.count > 1)
    #expect(chunks.allSatisfy { $0.unicodeScalars.count <= 510 })
    #expect(chunks.joined(separator: " ") == phonemes)
    let unbroken = String(repeating: "a\u{0303}", count: 600)
    let hardChunks = KokoroEnglishFrontend.chunks(unbroken)
    #expect(hardChunks.allSatisfy { $0.unicodeScalars.count <= 510 })
    #expect(hardChunks.joined() == unbroken)
  }
}
