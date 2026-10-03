import AVFoundation
import Foundation
import Synchronization

/// `record [<id>]`: records Aidan's dictation samples from the system default input.
///
/// With an id it redoes that one recording. Without, it walks through every recorded-source
/// sample that still has none, in manifest order. Everything is checked before the microphone
/// is touched, so a bad id fails without a permission prompt.
func record(id: String?, in manifest: Manifest) async throws {
  let targets = try recordingTargets(id: id, in: manifest)
  guard !targets.isEmpty else {
    print("Every recorded dictation sample already has a recording.")
    return
  }
  try await requireMicrophoneAccess()

  for (index, sample) in targets.enumerated() {
    var outcome: TakeOutcome
    repeat {
      outcome = try recordTake(of: sample, position: (index + 1, targets.count), offersQuit: id == nil)
    } while outcome == .redo
    if outcome == .quit { break }
  }
  if id == nil { print("\n" + recordingSummary(of: manifest)) }
}

private enum TakeOutcome { case keep, redo, quit }

/// The samples to record: the named one, or every one still missing a recording.
private func recordingTargets(id: String?, in manifest: Manifest) throws -> [Dictation] {
  let recordable = manifest.samples.compactMap { sample -> Dictation? in
    if case .dictation(let dictation) = sample, dictation.source == .recorded { dictation } else { nil }
  }
  guard let id else {
    return recordable.filter { !FileManager.default.fileExists(atPath: BenchData.recording($0.id).path) }
  }
  guard let sample = recordable.first(where: { $0.id == id }) else {
    throw RecordError("\(id) is not a dictation sample with source recorded")
  }
  return [sample]
}

private func recordTake(
  of sample: Dictation, position: (Int, Int), offersQuit: Bool
) throws -> TakeOutcome {
  let destination = BenchData.recording(sample.id)
  print("\n[\(position.0)/\(position.1)] \(sample.id)\n")
  print("  \(sample.prompt)")
  if let script = sample.script { print("\n  \"\(script)\"") }
  print("\nInput: \(AVCaptureDevice.default(for: .audio)?.localizedName ?? "none"), first channel")
  if FileManager.default.fileExists(atPath: destination.path) {
    print("A recording exists and will be replaced.")
  }

  _ = prompt("Press Return to start, and Return again to stop.")
  var inputClosed = false
  let take = try Take.record(untilReturn: { inputClosed = readLine() == nil })
  // Nothing is written for a take that was abandoned or empty, so an existing recording
  // survives and an empty file never marks the sample as recorded.
  if inputClosed { fail("\nInput closed. Nothing saved for \(sample.id).") }
  guard !take.samples.isEmpty else {
    print("Nothing was captured. Try again.")
    return .redo
  }
  try writeWAV(take.samples, to: destination)

  let isSilence = sample.reference == ""
  print(String(format: "Saved %.1fs, peak %.0f dBFS.", take.duration, take.peakDecibels))
  if take.peakDecibels < -40 && !isSilence {
    print("WARNING: this is almost silent. Mic permission may be denied or the wrong input selected.")
  }
  if take.peakDecibels > -0.1 { print("WARNING: this clipped. Lower the input level and redo it.") }
  if take.droppedBuffers > 0 {
    print("WARNING: \(take.droppedBuffers) buffers failed to convert, so the take has gaps. Redo it.")
  }

  let keys = offersQuit ? "Return keeps it, r redoes it, q quits." : "Return keeps it, r redoes it."
  switch prompt(keys) {
  case "r": return .redo
  case "q" where offersQuit: return .quit
  default: return .keep
  }
}

/// Prints a message and returns the lowercased answer. End of input ends the session.
private func prompt(_ message: String) -> String {
  print(message, terminator: " ")
  guard let line = readLine() else { fail("\nInput closed.") }
  return line.trimmingCharacters(in: .whitespaces).lowercased()
}

private func recordingSummary(of manifest: Manifest) -> String {
  let missing = (try? recordingTargets(id: nil, in: manifest)) ?? []
  return missing.isEmpty
    ? "All recorded dictation samples have a recording."
    : "Still missing a recording (\(missing.count)): " + missing.map(\.id).joined(separator: ", ")
}

private func requireMicrophoneAccess() async throws {
  guard await AVCaptureDevice.requestAccess(for: .audio) else {
    throw RecordError(
      "Microphone access denied. Allow this terminal app in System Settings > Privacy & Security > Microphone."
    )
  }
}

struct RecordError: LocalizedError {
  let errorDescription: String?
  init(_ description: String) { errorDescription = description }
}

/// One capture from the default input: 16 kHz mono Int16, resampled by `AVAudioConverter`.
///
/// The tap runs on an audio thread while the main thread waits for Return, so the converter
/// and the samples sit behind one lock.
private final class Take: Sendable {
  private struct State {
    let converter: AVAudioConverter
    var samples: [Int16] = []
    var droppedBuffers = 0
  }

  static let format = AVAudioFormat(
    commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

  private let state: Mutex<State>

  private init(converter: AVAudioConverter) { state = Mutex(State(converter: converter)) }

  /// Captures until `stop` returns.
  static func record(
    untilReturn stop: () -> Void
  ) throws -> (samples: [Int16], duration: Double, peakDecibels: Double, droppedBuffers: Int) {
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let inputFormat = input.outputFormat(forBus: 0)
    guard inputFormat.sampleRate > 0, let converter = AVAudioConverter(from: inputFormat, to: format)
    else { throw RecordError("No usable input device.") }
    // Take the first channel. Downmixing silences discrete multichannel layouts, which
    // unlabelled USB and aggregate devices report, and weights surround layouts.
    converter.channelMap = [0]

    let take = Take(converter: converter)
    input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
      take.append(buffer)
    }
    try engine.start()
    stop()
    // Let the tap deliver what it has buffered, so the last words aren't cut off.
    Thread.sleep(forTimeInterval: 0.3)
    engine.stop()
    input.removeTap(onBus: 0)

    let (samples, dropped) = take.state.withLock { ($0.samples, $0.droppedBuffers) }
    let peak = Double(samples.map { abs(Int32($0)) }.max() ?? 0) / 32768
    return (samples, Double(samples.count) / format.sampleRate, 20 * log10(max(peak, 1e-6)), dropped)
  }

  /// Converts one tap buffer. The block form is the one that resamples, keeping its history
  /// between calls so buffer boundaries neither drop nor repeat samples.
  private func append(_ buffer: AVAudioPCMBuffer) {
    state.withLock { state in
      let ratio = Self.format.sampleRate / buffer.format.sampleRate
      let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
      var supplied = false
      while let output = AVAudioPCMBuffer(pcmFormat: Self.format, frameCapacity: capacity) {
        let status = state.converter.convert(to: output, error: nil) { _, inputStatus in
          guard !supplied else {
            inputStatus.pointee = .noDataNow
            return nil
          }
          supplied = true
          inputStatus.pointee = .haveData
          return buffer
        }
        guard status != .error else {
          state.droppedBuffers += 1
          return
        }
        state.samples += UnsafeBufferPointer(
          start: output.int16ChannelData![0], count: Int(output.frameLength))
        // `.haveData` means the output filled before the input was used up; go round again.
        guard status == .haveData else { return }
      }
    }
  }
}

/// Writes 16 kHz mono 16-bit PCM WAV, which is what `WAVRecording` reads.
///
/// The file is written beside its destination and moved into place, so an interrupted take
/// never leaves a partial WAV under the real name.
func writeWAV(_ samples: [Int16], to destination: URL) throws {
  let directory = destination.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  // The extension tells AVAudioFile to write WAV.
  let partial = directory.appending(path: ".\(destination.lastPathComponent).partial.wav")
  defer { try? FileManager.default.removeItem(at: partial) }

  do {
    let file = try AVAudioFile(
      forWriting: partial, settings: Take.format.settings,
      commonFormat: .pcmFormatInt16, interleaved: true)
    let buffer = AVAudioPCMBuffer(pcmFormat: Take.format, frameCapacity: AVAudioFrameCount(max(samples.count, 1)))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    for (index, sample) in samples.enumerated() { buffer.int16ChannelData![0][index] = sample }
    try file.write(from: buffer)
    // The header is finalised when the file is released.
  }
  if FileManager.default.fileExists(atPath: destination.path) {
    _ = try FileManager.default.replaceItemAt(destination, withItemAt: partial)
  } else {
    try FileManager.default.moveItem(at: partial, to: destination)
  }
}
