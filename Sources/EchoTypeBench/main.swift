import Foundation

/// The bench's commands: `corpus status` and `record`.
let usage = """
  usage: EchoTypeBench corpus status [--manifest <path>]
         EchoTypeBench record [<id>] [--manifest <path>]
  record walks through the dictation samples still missing a recording, or redoes <id>.
  The manifest defaults to Corpus/manifest.json in the current directory.
  """

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
    print(corpusStatus(of: try Manifest.load(from: URL(fileURLWithPath: manifestPath))))
  case ("record", let ids) where ids.count <= 1:
    let manifest = try Manifest.load(from: URL(fileURLWithPath: manifestPath))
    try await record(id: ids.first, in: manifest)
  default:
    fail(usage)
  }
} catch let invalid as Manifest.Invalid {
  fail("\(manifestPath):\n\(invalid)")
} catch {
  fail(error.localizedDescription)
}
