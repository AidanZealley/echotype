import Foundation

/// The bench's commands: `corpus status`, `record`, `transcribe`, `cleanup`, `speak` and `report`.
let usage = """
  usage: EchoTypeBench corpus status [--manifest <path>]
         EchoTypeBench record [<id>] [--manifest <path>]
         EchoTypeBench transcribe --provider apple|xai|local [--candidate transcription=<name>] [--cleanup] [--candidate cleanup=<name>] [--fast] [--repeat <n>] [--synthetic] [<id>...] [--manifest <path>]
         EchoTypeBench cleanup --provider apple|xai|local [--candidate cleanup=<name>] [--fast] [--repeat <n>] [<id>...] [--manifest <path>]
         EchoTypeBench speak --provider apple|xai|local [--voice <id>] [--speed <x>] [--candidate <service>=<name>] [--fast] [--repeat <n>] [<id>...] [--manifest <path>]
         EchoTypeBench report <run-id-or-path>... [--manifest <path>]
         EchoTypeBench report --listen <run-id-or-path> <run-id-or-path>... [--manifest <path>]
  record walks through the dictation samples still missing a recording, or redoes <id>.
  transcribe feeds each dictation sample's audio (all with audio, or the ids) through the provider's
  live transcription at real-time pace, or without waiting with --fast, and writes a run directory
  under ~/Library/Application Support/EchoTypeBench/runs/. --synthetic uses generated audio.
  transcribe --cleanup also revises committed text live and inserts the final revision. It requires
  paced audio and a cleanup service, and prepares both local candidates.
  cleanup replays each cleanup sample's committed text (all, or the ids) through the real Reviser at
  real-time pace, or without waiting with --fast, into a run directory like transcribe's.
  --repeat <n> runs the selected samples n times in one process; the first request is reported as
  cold and the rest as warm. The commands also record how long the provider took to become ready
  and sample the process's memory, the thermal state, memory pressure and one-minute load average. run.json records debug or release.
  xAI reads its key from XAI_API_KEY. The local provider downloads its pinned models on first use;
  --candidate transcription=parakeet-unified|parakeet-unified-keyterms|whisper-turbo chooses its transcription model
  (default parakeet-unified), --candidate cleanup=qwen3-4b-2507|smollm3-3b its cleanup model (default
  qwen3-4b-2507) and --candidate voice=kokoro its voice model (default
  kokoro). A local run prepares the service it measures and every service named with --candidate,
  and keeps them loaded, so a combination's memory can be measured.
  speak reads each reading sample (all, or the ids) through the provider's voice, with --voice (default
  the first) at --speed (default 1), without making sound. A paced run models the app's player: it
  starts on the first chunk, holds 500 ms and drains in real time, pauses once for 5 s partway through
  passages tagged pause-resume, and ends each pass with a cancellation trial. --fast pulls without
  waiting, for first audio and synthesis speed. It writes each reading's WAV into the run directory.
  report scores transcribe runs (ids under runs/, or paths) against the reviewed references, and cleanup
  runs against the expected cleanups, and writes report.md into each run directory. Synthetic runs are
  not scored. speak runs are scored for first audio, gaps, real-time factor, pause and cancellation.
  report --listen writes a page into listening/ under the bench data directory, where the runs' readings of
  each passage play under shuffled labels and are rated blind, saved as JSON that names each label's run and
  voice, and prints the page's path.
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
    let options = try RunOptions(parsing: rest)
    try await transcribe(options, in: Manifest.load(from: URL(fileURLWithPath: manifestPath)))
  case ("cleanup", let rest):
    let options = try RunOptions(parsing: rest)
    try await cleanup(options, in: Manifest.load(from: URL(fileURLWithPath: manifestPath)))
  case ("speak", let rest):
    let options = try RunOptions(parsing: rest)
    try await speak(options, in: Manifest.load(from: URL(fileURLWithPath: manifestPath)))
  case ("report", let rest):
    let manifest = try Manifest.load(from: URL(fileURLWithPath: manifestPath))
    if let flag = rest.firstIndex(of: "--listen") {
      try listen(to: Array(rest[..<flag] + rest[(flag + 1)...]), in: manifest)
    } else {
      try report(rest, in: manifest)
    }
  default:
    fail(usage)
  }
} catch let invalid as Manifest.Invalid {
  fail("\(manifestPath):\n\(invalid)")
} catch {
  fail(error.localizedDescription)
}
