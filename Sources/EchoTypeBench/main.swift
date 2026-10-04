import Foundation

/// The bench's commands: `corpus status`, `record` and `transcribe`.
let usage = """
  usage: EchoTypeBench corpus status [--manifest <path>]
         EchoTypeBench record [<id>] [--manifest <path>]
         EchoTypeBench transcribe --provider apple|xai [--fast] [--synthetic] [<id>...] [--manifest <path>]
  record walks through the dictation samples still missing a recording, or redoes <id>.
  transcribe feeds each dictation sample's audio (all with audio, or the ids) through the provider's
  live transcription at real-time pace, or without waiting with --fast, and writes a run directory
  under ~/Library/Application Support/EchoTypeBench/runs/. --synthetic uses generated audio.
  xAI reads its key from XAI_API_KEY.
  The manifest defaults to Corpus/manifest.json in the current directory.
  """

/// A failure the bench reports to the terminal as is.
struct BenchError: LocalizedError {
  let errorDescription: String?
  init(_ description: String) { errorDescription = description }
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

var arguments = Array(CommandLine.arguments.dropFirst())
var manifestPath = "Corpus/manifest.json"
if let flag = arguments.firstIndex(of: "--manifest") {
  guard flag + 1 < arguments.count else { fail(usage) }
  manifestPath = arguments[flag + 1]
  arguments.removeSubrange(flag...(flag + 1))
}

do {
  switch (arguments.first, arguments.dropFirst().map { $0 }) {
  case ("corpus", ["status"]):
    let manifest = try Manifest.load(from: URL(fileURLWithPath: manifestPath))
    print(corpusStatus(of: manifest, references: try loadReferences()))
  case ("record", let ids) where ids.count <= 1:
    let manifest = try Manifest.load(from: URL(fileURLWithPath: manifestPath))
    try await record(id: ids.first, in: manifest)
  case ("transcribe", let rest):
    let options = try TranscribeOptions(parsing: rest)
    try await transcribe(options, in: Manifest.load(from: URL(fileURLWithPath: manifestPath)))
  default:
    fail(usage)
  }
} catch let invalid as Manifest.Invalid {
  fail("\(manifestPath):\n\(invalid)")
} catch {
  fail(error.localizedDescription)
}
