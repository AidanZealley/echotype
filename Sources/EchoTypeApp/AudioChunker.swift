import AVFoundation
import EchoTypeCore
import Synchronization

/// Converts what the device delivers and cuts it into one session's chunks.
///
/// The capture output calls it on its sample queue while the main actor ends it, so all of it
/// happens under one lock. That also orders the end: nothing captured after `end` is delivered.
/// Each session has its own, so a device still closing after its session ended feeds a chunker
/// that drops what it hears, never the next session's stream.
final class AudioChunker: NSObject, Sendable, AVCaptureAudioDataOutputSampleBufferDelegate {
  /// 100ms at 16 kHz mono Int16.
  private static let chunkBytes = 3_200

  private struct State {
    /// Nil once delivery has ended.
    var continuation: AsyncThrowingStream<Data, any Error>.Continuation?
    /// Made from the first buffer's format, and remade if the device's format changes.
    var converter: AVAudioConverter?
    /// Converted audio not yet a whole chunk.
    var pending = Data()
    /// Whether this delivery has reported a level yet.
    var reported = false
  }

  private let state: Mutex<State>
  /// Receives the level of the first buffer and then of each chunk, while delivering.
  private let onLevel: @MainActor @Sendable (Double) -> Void

  init(
    _ continuation: AsyncThrowingStream<Data, any Error>.Continuation,
    onLevel: @escaping @MainActor @Sendable (Double) -> Void
  ) {
    state = Mutex(State(continuation: continuation))
    self.onLevel = onLevel
  }

  private var isDelivering: Bool { state.withLock { $0.continuation != nil } }

  /// Finishes delivery. A clean end flushes the partial chunk; a failure does not.
  func end(throwing error: (any Error)? = nil) {
    state.withLock { state in
      if error == nil, !state.pending.isEmpty { state.continuation?.yield(state.pending) }
      state.continuation?.finish(throwing: error)
      state = State()
    }
  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let level = receive(sampleBuffer) else { return }
    // A level measured just before `end` can arrive on the main actor after it.
    Task { @MainActor in if isDelivering { onLevel(level) } }
  }

  /// Delivers the buffer. Returns the level to report, if any: that of the first buffer, so
  /// the overlay knows audio is flowing, and then that of each whole chunk sent.
  private func receive(_ sampleBuffer: CMSampleBuffer) -> Double? {
    state.withLock { state in
      guard let continuation = state.continuation else { return nil }
      let converted: Data
      do {
        let buffer = try Self.pcmBuffer(from: sampleBuffer)
        if state.converter?.inputFormat != buffer.format {
          state.converter = try Self.makeConverter(from: buffer.format)
        }
        converted = try Self.convert(buffer, with: state.converter!)
      } catch {
        continuation.finish(throwing: AudioCapture.Failure.captureFailed(error))
        state = State()
        return nil
      }
      state.pending.append(converted)
      var sent = 0
      while state.pending.count - sent >= Self.chunkBytes {
        continuation.yield(Data(state.pending[sent..<sent + Self.chunkBytes]))
        sent += Self.chunkBytes
      }
      // The level of what is sent, measured after conversion, so any format reads the same.
      let measured = sent > 0 ? state.pending[..<sent] : state.reported ? nil : converted
      // A fresh copy of the tail. `removeFirst` on `Data` keeps the consumed bytes allocated,
      // so the buffer would grow for the length of the session.
      if sent > 0 { state.pending = Data(state.pending[sent...]) }
      guard let measured else { return nil }
      state.reported = true
      return Overlay.level(rms: Self.rms(of: measured))
    }
  }

  /// Copies a sample buffer's audio into a PCM buffer in the format it arrived in.
  private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) throws -> AVAudioPCMBuffer {
    let frames = sampleBuffer.numSamples
    guard let description = sampleBuffer.formatDescription,
      var stream = description.audioStreamBasicDescription,
      stream.mFormatID == kAudioFormatLinearPCM,
      let format = AVAudioFormat(
        streamDescription: &stream, channelLayout: channelLayout(of: description, stream)),
      frames > 0,
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))
    else { throw CaptureError("unsupported audio: \(String(describing: sampleBuffer))") }
    // Set first: the buffer list the copy fills reports its size from the frame length, and a
    // copy into a list sized 0 fails (-12731).
    buffer.frameLength = AVAudioFrameCount(frames)
    let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
      sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
    guard status == noErr else { throw CaptureError("could not read audio (\(status))") }
    return buffer
  }

  /// The layout `AVAudioFormat` needs for more than two channels, and nil otherwise.
  private static func channelLayout(
    of description: CMAudioFormatDescription, _ stream: AudioStreamBasicDescription
  ) -> AVAudioChannelLayout? {
    guard stream.mChannelsPerFrame > 2,
      let layout = CMAudioFormatDescriptionGetChannelLayout(description, sizeOut: nil)
    else { return nil }
    return AVAudioChannelLayout(layout: layout)
  }

  /// RMS amplitude of 16-bit samples, with full scale at 1.
  private static func rms(of samples: Data) -> Float {
    let count = samples.count / 2
    guard count > 0 else { return 0 }
    let sum = samples.withUnsafeBytes { bytes in
      (0..<count).reduce(Float(0)) { sum, index in
        let sample = Float(bytes.loadUnaligned(fromByteOffset: index * 2, as: Int16.self)) / 32_768
        return sum + sample * sample
      }
    }
    return (sum / Float(count)).squareRoot()
  }

  private static func makeConverter(from input: AVAudioFormat) throws -> AVAudioConverter {
    guard
      let output = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
      let converter = AVAudioConverter(from: input, to: output)
    else { throw CaptureError("no converter from \(input)") }
    // Mix every channel into mono rather than keeping only the first.
    converter.downmix = true
    return converter
  }

  /// Converts one buffer. The block form is the one that resamples; the resampler keeps its
  /// own history between calls, so buffer boundaries neither drop nor repeat samples.
  private static func convert(
    _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter
  ) throws -> Data {
    let ratio = converter.outputFormat.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
    var supplied = false
    var data = Data()
    while true {
      guard
        let output = AVAudioPCMBuffer(
          pcmFormat: converter.outputFormat, frameCapacity: capacity)
      else { throw CaptureError("could not allocate an output buffer") }
      var error: NSError?
      let status = converter.convert(to: output, error: &error) { _, inputStatus in
        guard !supplied else {
          // More will come with the next buffer; this is not the end of the stream.
          inputStatus.pointee = .noDataNow
          return nil
        }
        supplied = true
        inputStatus.pointee = .haveData
        return buffer
      }
      if status == .error { throw error ?? CaptureError("conversion failed") }
      // Int16 in memory is little-endian on every Mac this runs on.
      data.append(Data(bytes: output.int16ChannelData![0], count: Int(output.frameLength) * 2))
      // `.haveData` means the output filled before the input was used up; go round again.
      guard status == .haveData else { return data }
    }
  }
}

/// Worded for the controller, which shows `localizedDescription` after "Microphone failed:".
struct CaptureError: LocalizedError {
  let errorDescription: String?
  init(_ description: String) { errorDescription = description }
}
