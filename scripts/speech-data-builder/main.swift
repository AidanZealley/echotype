import Foundation
import libespeak_ng

// Build-time only. The pinned dependency supplies the compiler and all its source data.
let source = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let files = FileManager.default
if files.fileExists(atPath: output.path) { try files.removeItem(at: output) }
try files.createDirectory(at: output, withIntermediateDirectories: true)
let data = output.appending(path: "espeak-ng-data")
try files.copyItem(at: source.appending(path: "espeak-ng-data").resolvingSymlinksInPath(), to: data)
espeak_ng_InitializePath(output.path)
let log = fopen("/dev/null", "w")
defer { if let log { fclose(log) } }
let phonemes = source.appending(path: "phsource").path
guard espeak_ng_CompileIntonationPath(phonemes, nil, log, nil) == ENS_OK,
  espeak_ng_CompilePhonemeDataPath(22050, phonemes, nil, log, nil) == ENS_OK,
  espeak_SetVoiceByName("en-us") == EE_OK,
  espeak_ng_CompileDictionary(source.appending(path: "dictsource").path + "/", "en", log, 0, nil) == ENS_OK
else { fatalError("Could not compile the pinned English pronunciation data.") }
// Retain only the data used by our two accents, excluding compiler debug manifests.
let keep = Set(["en_dict", "phondata", "phonindex", "phontab", "intonations", "lang"])
for url in try files.contentsOfDirectory(at: data, includingPropertiesForKeys: nil) where !keep.contains(url.lastPathComponent) {
  try files.removeItem(at: url)
}
let lang = data.appending(path: "lang")
let english = try Data(contentsOf: lang.appending(path: "gmw/en"))
let american = try Data(contentsOf: lang.appending(path: "gmw/en-US"))
try files.removeItem(at: lang)
try files.createDirectory(at: lang.appending(path: "gmw"), withIntermediateDirectories: true)
try english.write(to: lang.appending(path: "gmw/en"))
try american.write(to: lang.appending(path: "gmw/en-US"))
try files.copyItem(at: source.deletingLastPathComponent().deletingLastPathComponent().appending(path: "LICENSE"),
  to: output.appending(path: "COPYING.txt"))
try Data("eSpeak NG English data compiled from espeak-ng-spm fd28f6460cc4cdf631528c8e2f7bd825747aac5c. GPL-3.0.\n".utf8)
  .write(to: output.appending(path: "SOURCE.txt"))
