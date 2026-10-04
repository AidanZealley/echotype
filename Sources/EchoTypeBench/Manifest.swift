import EchoTypeCore
import Foundation

/// `Corpus/manifest.json`: the keyterms and every sample the bench can run. Committed, while
/// the audio it refers to stays outside git.
struct Manifest: Decodable {
  let version: Int
  let keyterms: [String]
  let samples: [Sample]

  /// Reads and validates the manifest, so a broken corpus stops a command before it does work.
  static func load(from url: URL) throws -> Manifest {
    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    let problems = manifest.problems
    guard problems.isEmpty else { throw Invalid(problems: problems) }
    return manifest
  }

  struct Invalid: Error, CustomStringConvertible {
    let problems: [String]
    var description: String { problems.joined(separator: "\n") }
  }

  /// Every problem found, each naming its sample.
  var problems: [String] {
    var seen = Set<String>()
    var problems: [String] = []
    for sample in samples {
      if !seen.insert(sample.id).inserted { problems.append("\(sample.id): duplicate id") }
      if case .cleanup(let cleanup) = sample, !cleanup.expectedOnlyDeletesWords {
        problems.append("\(sample.id): expected is not a subsequence of the segments' words")
      }
    }
    return problems
  }
}

/// The three kinds of sample, discriminated by `kind` in the JSON.
enum Sample: Decodable {
  case dictation(Dictation)
  case cleanup(Cleanup)
  case reading(Reading)

  var id: String {
    switch self {
    case .dictation(let sample): sample.id
    case .cleanup(let sample): sample.id
    case .reading(let sample): sample.id
    }
  }

  private enum Kind: String, Decodable { case dictation, cleanup, reading }
  private enum CodingKeys: String, CodingKey { case kind }

  init(from decoder: any Decoder) throws {
    switch try decoder.container(keyedBy: CodingKeys.self).decode(Kind.self, forKey: .kind) {
    case .dictation: self = .dictation(try Dictation(from: decoder))
    case .cleanup: self = .cleanup(try Cleanup(from: decoder))
    case .reading: self = .reading(try Reading(from: decoder))
    }
  }
}

/// Speech for a provider to transcribe.
struct Dictation: Decodable {
  enum Source: String, Decodable { case recorded, synthetic }

  let id: String
  let source: Source
  /// What Aidan is asked to do when recording.
  let prompt: String
  /// The words to read aloud. Natural clips have none.
  let script: String?
  let tags: [String]
}

/// Committed text as it arrives, for the `Reviser` to clean up.
struct Cleanup: Decodable {
  struct Segment: Decodable {
    /// Seconds after the start at which the text arrives.
    let at: Double
    let text: String
  }

  let id: String
  let segments: [Segment]
  let expected: String
  let tags: [String]
  /// More than one edit is reasonable, so scoring leaves it to manual judgement.
  let ambiguous: Bool

  /// Cleanup only deletes words, so the expected text must be what is left of the input.
  var expectedOnlyDeletesWords: Bool {
    deletedIndices(from: Prose.words(segments.map(\.text).joined(separator: " ")), leaving: Prose.words(expected)) != nil
  }
}

/// A passage for a voice to read, with the features a listener should check.
struct Reading: Decodable {
  let id: String
  let text: String
  let checks: [String]
  let tags: [String]
}
