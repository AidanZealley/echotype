import EchoTypeCore
import Foundation
import Synchronization

// What a run measures about the machine and the provider, beyond what its samples record: how
// long the provider took to become ready, the process's memory and the system's thermal and
// memory state, and how `Reviser`'s cancellation and deadline behaved. Shared by `transcribe`
// and `cleanup`; `report` reads it back.

// MARK: Preparation

/// How long the provider took to become ready, and what it said while it waited. Written to
/// `preparation.json`.
struct Preparation: Codable {
  struct Message: Codable {
    /// Milliseconds after `startedAt`.
    let ms: Double
    let message: String
  }

  let startedAt: Date
  let readyAt: Date
  let messages: [Message]

  var waitMs: Double { readyAt.timeIntervalSince(startedAt) * 1000 }

  /// The messages grouped by what they say before their numbers, with how long each phase
  /// lasted. Download progress changes its text with every percent, so "Downloading models, 1.2
  /// of 2.3 GB" and "Downloading models, 1.3 of 2.3 GB" are one phase, told apart from "Loading
  /// the cleanup model".
  var phases: [(name: String, ms: Double)] {
    var starts: [(name: String, at: Double)] = []
    for message in messages {
      let name = String(message.message.prefix { !$0.isNumber }).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
      if starts.last?.name != name { starts.append((name, message.ms)) }
    }
    return starts.indices.map { index in
      let end = index + 1 < starts.count ? starts[index + 1].at : waitMs
      return (starts[index].name, max(0, end - starts[index].at))
    }
  }
}

// MARK: Sampler

/// One reading of the bench process and the system.
struct MachineSample: Codable {
  let at: Date
  /// The process's `phys_footprint`, which counts compressed and GPU-wired memory that resident
  /// size misses.
  let footprintBytes: UInt64
  /// A name from `thermalStates`.
  let thermalState: String
  /// A name from `memoryPressureLevels`, in order of severity.
  let memoryPressure: String
}

let thermalStates = ["nominal", "fair", "serious", "critical"]
let memoryPressureLevels = ["normal", "warning", "critical"]

/// Samples the process and the system every 250 ms from creation until `stop`, and whenever
/// asked. Samples are held in memory because the run directory does not exist while the
/// provider is still preparing.
final class Sampler: Sendable {
  private let samples = Mutex<[MachineSample]>([])
  private let loop = Mutex<Task<Void, Never>?>(nil)

  init() {
    sampleNow()
    loop.withLock {
      $0 = Task {
        while (try? await Task.sleep(for: .milliseconds(250))) != nil { self.sampleNow() }
      }
    }
  }

  func sampleNow() {
    let sample = MachineSample(
      at: Date(), footprintBytes: physFootprint(), thermalState: thermalStateName(),
      memoryPressure: memoryPressureName())
    samples.withLock { $0.append(sample) }
  }

  /// Stops sampling and writes `sampler.json`.
  func stop(writingTo directory: URL) throws {
    loop.withLock { $0?.cancel() }
    sampleNow()
    try writeJSON(samples.withLock { $0 }, to: directory.appending(path: "sampler.json"))
  }
}

private func physFootprint() -> UInt64 {
  var info = task_vm_info_data_t()
  var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
  let status = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
    }
  }
  return status == KERN_SUCCESS ? info.phys_footprint : 0
}

private func thermalStateName() -> String {
  switch ProcessInfo.processInfo.thermalState {
  case .nominal: "nominal"
  case .fair: "fair"
  case .serious: "serious"
  case .critical: "critical"
  @unknown default: "critical"
  }
}

/// The kernel's pressure level: 1 normal, 2 warning, 4 critical.
private func memoryPressureName() -> String {
  var level: Int32 = 0
  var size = MemoryLayout<Int32>.size
  guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return "normal" }
  return level >= 4 ? "critical" : level >= 2 ? "warning" : "normal"
}

// MARK: Cancellation and deadline

/// From calling `finish` to the end of the live revision it cancelled. Nil when `finish` found
/// none running.
func cancellationLatencyMs(of attempts: [DictationTrace.Revision], finishCalledAt: Date) -> Double? {
  guard let live = attempts.last(where: { !$0.isFinal && $0.result == .cancelled }) else { return nil }
  let end = live.at.addingTimeInterval(live.duration)
  return max(0, end.timeIntervalSince(finishCalledAt)) * 1000
}

/// What `Reviser`'s three-second timer did to the final revision.
struct DeadlineOutcome: Equatable {
  /// The timer cancelled the final revision, so the dictation inserted unrevised words.
  let fellBack: Bool
  /// The final revision ended over 250 ms after the deadline, so cancellation could not
  /// interrupt the model.
  let overran: Bool
}

func deadlineOutcome(of attempts: [DictationTrace.Revision]) -> DeadlineOutcome {
  guard let final = attempts.last(where: \.isFinal) else { return DeadlineOutcome(fellBack: false, overran: false) }
  return DeadlineOutcome(
    fellBack: final.result == .cancelled, overran: final.duration > Reviser.finalTimeout + 0.25)
}

// MARK: Cold and warm

/// Durations in seconds of the requests the model served: every final revision and every live
/// revision that `finish` did not cancel, which stopped early and says nothing about how long a
/// request takes. The cold sample's first such request is the run's cold request; every other
/// one is warm.
func requestDurations(cold: [DictationTrace.Revision], warm: [[DictationTrace.Revision]]) -> (cold: Double?, warm: [Double]) {
  let served = { (attempts: [DictationTrace.Revision]) in
    attempts.filter { $0.isFinal || $0.result != .cancelled }.map(\.duration)
  }
  let coldSample = served(cold)
  return (coldSample.first, Array(coldSample.dropFirst()) + warm.flatMap(served))
}

/// A result that may come from a run with repeats.
protocol RepeatedResult {
  /// Nil in runs from before repeats existed.
  var repeatIndex: Int? { get }
}

/// The first request after the provider becomes ready is cold: it is the run's first result.
/// Runs from before repeats existed did not mark it, so all their results count as warm.
func splitCold<Result: RepeatedResult>(_ results: [Result]) -> (cold: Result?, warm: [Result]) {
  guard let first = results.first, first.repeatIndex != nil else { return (nil, results) }
  return (first, Array(results.dropFirst()))
}

// MARK: Files

/// ISO 8601 with milliseconds, because `.iso8601` drops them and revision times need them.
/// Decoding also reads the whole-second form that earlier runs wrote.
extension JSONEncoder.DateEncodingStrategy {
  static let milliseconds = custom { date, encoder in
    var container = encoder.singleValueContainer()
    try container.encode(date.formatted(.iso8601WithMilliseconds))
  }
}

extension JSONDecoder.DateDecodingStrategy {
  static let secondsOrMilliseconds = custom { decoder in
    let text = try decoder.singleValueContainer().decode(String.self)
    return try (try? Date(text, strategy: .iso8601WithMilliseconds)) ?? Date(text, strategy: .iso8601)
  }
}

private extension ParseStrategy where Self == Date.ISO8601FormatStyle {
  static var iso8601WithMilliseconds: Date.ISO8601FormatStyle { .init(includingFractionalSeconds: true) }
}

private extension FormatStyle where Self == Date.ISO8601FormatStyle {
  static var iso8601WithMilliseconds: Date.ISO8601FormatStyle { .init(includingFractionalSeconds: true) }
}

func writeJSON(_ value: some Encodable, to file: URL) throws {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  encoder.dateEncodingStrategy = .milliseconds
  try encoder.encode(value).write(to: file)
}

/// A run's `preparation.json` and `sampler.json`, each absent from runs before they existed.
struct RunMeasurements {
  let preparation: Preparation?
  let samples: [MachineSample]

  init(directory: URL) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsOrMilliseconds
    let read = { (file: String) in try? Data(contentsOf: directory.appending(path: file)) }
    preparation = read("preparation.json").flatMap { try? decoder.decode(Preparation.self, from: $0) }
    samples = read("sampler.json").flatMap { try? decoder.decode([MachineSample].self, from: $0) } ?? []
  }

  /// "preparation 1840 ms (Downloading models 900 ms, Loading the cleanup model 940 ms)".
  var preparationText: String? {
    guard let preparation else { return nil }
    let phases = preparation.phases.map { "\($0.name) \(Int($0.ms.rounded())) ms" }.joined(separator: ", ")
    return "preparation \(Int(preparation.waitMs.rounded())) ms" + (phases.isEmpty ? "" : " (\(phases))")
  }

  /// "footprint peak 912 MiB, ready 640 MiB, thermal worst nominal, memory pressure worst normal".
  /// The ready footprint is the first reading once the provider was ready, before the first request.
  var machineText: String? {
    guard !samples.isEmpty else { return nil }
    let mebibytes = { (bytes: UInt64) in "\(bytes / 1_048_576) MiB" }
    let worst = { (names: [String], order: [String]) in
      names.max { order.firstIndex(of: $0) ?? 0 < order.firstIndex(of: $1) ?? 0 } ?? "—"
    }
    var parts = ["footprint peak " + mebibytes(samples.map(\.footprintBytes).max() ?? 0)]
    if let readyAt = preparation?.readyAt, let ready = samples.first(where: { $0.at >= readyAt }) {
      parts.append("ready " + mebibytes(ready.footprintBytes))
    }
    parts.append("thermal worst " + worst(samples.map(\.thermalState), thermalStates))
    parts.append("memory pressure worst " + worst(samples.map(\.memoryPressure), memoryPressureLevels))
    return parts.joined(separator: ", ")
  }
}
