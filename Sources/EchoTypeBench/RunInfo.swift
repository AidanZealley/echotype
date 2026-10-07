import EchoTypeCore
import Foundation

/// What a run directory records about where and how it ran, written as `run.json` before any
/// sample runs so that an interrupted run is still described.
struct RunInfo: Encodable {
  let command: String
  let arguments: [String]
  let provider: String
  /// The candidates a local run used. Nil for providers without any.
  let candidates: LocalSelection?
  let fast: Bool
  let synthetic: Bool
  let macModel: String?
  let macOS: String
  /// Nil when the bench is not run from a git checkout.
  let sourceRevision: String?
  /// Whether the working tree had uncommitted changes, so the revision alone does not say what ran.
  let sourceDirty: Bool?
  let startedAt: Date

  /// Creates `runs/<UTC timestamp>-<provider>/` under the bench data directory and writes its
  /// `run.json`. The Swift toolchain is not recorded: asking for it means spawning `swift`.
  static func begin(
    command: String, arguments: [String], provider: String, candidates: LocalSelection?, fast: Bool,
    synthetic: Bool
  ) throws -> URL {
    let now = Date()
    let stamp = DateFormatter()
    stamp.locale = Locale(identifier: "en_US_POSIX")
    stamp.timeZone = TimeZone(identifier: "UTC")
    stamp.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    let directory = BenchData.directory.appending(path: "runs/\(stamp.string(from: now))-\(provider)")
    try FileManager.default.createDirectory(
      at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

    let revision = git(["rev-parse", "HEAD"])
    let info = RunInfo(
      command: command, arguments: arguments, provider: provider, candidates: candidates, fast: fast,
      synthetic: synthetic,
      macModel: sysctlString("hw.model"),
      macOS: ProcessInfo.processInfo.operatingSystemVersionString,
      sourceRevision: revision,
      sourceDirty: revision == nil ? nil : !(git(["status", "--porcelain"]) ?? "").isEmpty,
      startedAt: now)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(info).write(to: directory.appending(path: "run.json"))
    return directory
  }
}

private func sysctlString(_ name: String) -> String? {
  var size = 0
  guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
  var buffer = [CChar](repeating: 0, count: size)
  guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
  return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

/// The trimmed output of `git <arguments>` in the current directory, or nil if it fails.
private func git(_ arguments: [String]) -> String? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
  process.arguments = arguments
  let output = Pipe()
  process.standardOutput = output
  process.standardError = FileHandle.nullDevice
  guard (try? process.run()) != nil else { return nil }
  let data = output.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else { return nil }
  return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}
