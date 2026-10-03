import Foundation

/// The bench's commands. Only `corpus status` exists so far.
let usage = """
  usage: EchoTypeBench corpus status [--manifest <path>]
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

guard arguments == ["corpus", "status"] else { fail(usage) }
do {
  let manifest = try Manifest.load(from: URL(fileURLWithPath: manifestPath))
  print(corpusStatus(of: manifest))
} catch let invalid as Manifest.Invalid {
  fail("\(manifestPath):\n\(invalid)")
} catch {
  fail("\(manifestPath): \(error.localizedDescription)")
}
