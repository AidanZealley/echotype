import Foundation

/// Where the bench keeps what is too large or too personal for git.
enum BenchData {
  static let directory = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appending(path: "EchoTypeBench", directoryHint: .isDirectory)

  /// Aidan's recording of a dictation sample.
  static func recording(_ id: String) -> URL {
    directory.appending(path: "audio/\(id).wav")
  }

  /// Generated speech, kept apart so that it can never stand in for a recording.
  static func syntheticAudio(_ id: String) -> URL {
    directory.appending(path: "audio/synthetic/\(id).wav")
  }
}

/// What to ask Aidan for, in plain text for a terminal.
func corpusStatus(of manifest: Manifest) -> String {
  let exists = { (url: URL) in FileManager.default.fileExists(atPath: url.path) }
  var dictations: [Dictation] = []
  var cleanups = 0
  var readings = 0
  for sample in manifest.samples {
    switch sample {
    case .dictation(let dictation): dictations.append(dictation)
    case .cleanup: cleanups += 1
    case .reading: readings += 1
    }
  }

  let unrecorded = dictations.filter {
    $0.source == .recorded && !exists(BenchData.recording($0.id))
  }
  let unreviewed = dictations.filter { $0.reference == nil }
  let scripted = dictations.filter { $0.script != nil }
  let synthetic = scripted.filter { exists(BenchData.syntheticAudio($0.id)) }

  var lines = [
    "samples: \(dictations.count) dictation, \(cleanups) cleanup, \(readings) reading",
    "synthetic audio: \(synthetic.count) of \(scripted.count) scripted dictation samples",
  ]
  lines += section("missing a recording", unrecorded.map(\.id))
  lines += section("reference not reviewed", unreviewed.map(\.id))
  return lines.joined(separator: "\n")
}

private func section(_ title: String, _ ids: [String]) -> [String] {
  ["", "\(title) (\(ids.count)):"] + ids.map { "  \($0)" }
}
