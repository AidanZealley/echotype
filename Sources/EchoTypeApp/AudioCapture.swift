import AVFoundation
import Synchronization

/// The microphone, as a dictation session needs it: 16 kHz mono little-endian Int16, in chunks
/// of roughly 100ms, ready for `SessionMachine.send(audio:)`.
///
/// The device is held only while a session is listening, so the macOS microphone indicator
/// clears as soon as the session ends. `start()` opens the device and starts delivering;
/// `stop()` ends delivery and closes it. Every session pays the 100 to 300ms device open
/// before audio flows.
///
/// The engine follows the system default input device by never choosing one. When that device
/// changes the engine stops itself, and a session in progress reopens it at once and carries
/// on from the new device.
@MainActor final class AudioCapture {
  enum Failure: Error {
    /// The user refused microphone access, now or earlier. Only System Settings can undo it.
    case microphoneDenied
    /// There is no input device to open.
    case noInputDevice
    /// `AVAudioEngine` would not start, or audio could not be converted.
    case engineFailed(any Error)
  }

  private let chunker = Chunker()
  private var engine: AVAudioEngine?
  private var deviceObserver: (any NSObjectProtocol)?

  /// Opens the device and starts delivering chunks.
  ///
  /// The stream yields chunks in capture order and finishes when `stop()` is called. It throws
  /// `Failure.engineFailed` if the device is lost mid-session and cannot be reopened, or if
  /// conversion fails. Starting again finishes the previous stream.
  func start() async throws(Failure) -> AsyncThrowingStream<Data, any Error> {
    try await openDevice()
    let (stream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
    chunker.begin(continuation)
    return stream
  }

  /// Stops delivering, sends whatever is left of the last chunk, finishes the stream and
  /// closes the device. Calling it again does nothing.
  func stop() {
    // Delivery ends first, under the chunker's lock, so closing the device loses nothing
    // that would have been sent. Audio the tap has not yet received when delivery ends (up
    // to one tap buffer, about 100ms) is not sent.
    chunker.end()
    closeDevice()
  }

  /// Asks for microphone access the first time, then opens the default input device. Does
  /// nothing if the device is already open.
  private func openDevice() async throws(Failure) {
    guard engine == nil else { return }
    guard await AVCaptureDevice.requestAccess(for: .audio) else { throw .microphoneDenied }
    // Another caller may have opened the device while this one waited.
    guard engine == nil else { return }

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else { throw .noInputDevice }
    chunker.install(on: input, format: format)
    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      throw .engineFailed(error)
    }

    self.engine = engine
    deviceObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.deviceChanged() }
    }
  }

  /// The default input device changed, or the one in use went away. The engine has already
  /// stopped. Reopen it on whatever the default is now, but only for a session in progress.
  private func deviceChanged() {
    closeDevice()
    guard chunker.isDelivering else { return }
    Task {
      do {
        try await openDevice()
      } catch {
        chunker.end(throwing: error)
        return
      }
      // The session may have ended while the device was reopening.
      if !chunker.isDelivering { closeDevice() }
    }
  }

  private func closeDevice() {
    guard let engine else { return }
    if let deviceObserver { NotificationCenter.default.removeObserver(deviceObserver) }
    deviceObserver = nil
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    self.engine = nil
  }
}

/// Converts what the tap hears and cuts it into chunks.
///
/// The tap calls `receive` on an audio thread while the main actor calls `begin` and `end`, so
/// all of it happens under one lock. That also orders the edges: nothing captured after `end`
/// is delivered, and nothing captured before `begin` is.
private final class Chunker: Sendable {
  /// 100ms at 16 kHz mono Int16.
  private static let chunkBytes = 3_200

  private struct State {
    var continuation: AsyncThrowingStream<Data, any Error>.Continuation?
    /// Made from the first buffer's format, and remade if the device's format changes.
    var converter: AVAudioConverter?
    /// Converted audio not yet a whole chunk.
    var pending = Data()
  }

  private let state = Mutex(State())

  var isDelivering: Bool { state.withLock { $0.continuation != nil } }

  /// Installs the tap. Nonisolated so the tap block is too: a block formed on the main actor
  /// would trap when the engine calls it from its audio thread.
  func install(on input: AVAudioInputNode, format: AVAudioFormat) {
    // The buffer size is a hint the engine may ignore; `receive` chunks whatever arrives.
    input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [self] buffer, _ in
      receive(buffer)
    }
  }

  func begin(_ continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
    state.withLock { state in
      state.continuation?.finish()
      // A fresh converter, so no resampler history leaks in from the previous session.
      state = State(continuation: continuation)
    }
  }

  /// Finishes delivery. A clean end flushes the partial chunk; a failure does not.
  func end(throwing error: (any Error)? = nil) {
    state.withLock { state in
      if error == nil, !state.pending.isEmpty { state.continuation?.yield(state.pending) }
      state.continuation?.finish(throwing: error)
      state = State()
    }
  }

  private func receive(_ buffer: AVAudioPCMBuffer) {
    state.withLock { state in
      guard let continuation = state.continuation else { return }
      do {
        if state.converter?.inputFormat != buffer.format {
          state.converter = try makeConverter(from: buffer.format)
        }
        state.pending.append(try convert(buffer, with: state.converter!))
      } catch {
        continuation.finish(throwing: AudioCapture.Failure.engineFailed(error))
        state = State()
        return
      }
      var sent = 0
      while state.pending.count - sent >= Self.chunkBytes {
        continuation.yield(Data(state.pending[sent..<sent + Self.chunkBytes]))
        sent += Self.chunkBytes
      }
      // A fresh copy of the tail. `removeFirst` on `Data` keeps the consumed bytes allocated,
      // so the buffer would grow for the length of the session.
      if sent > 0 { state.pending = Data(state.pending[sent...]) }
    }
  }

  private func makeConverter(from input: AVAudioFormat) throws -> AVAudioConverter {
    guard
      let output = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
      let converter = AVAudioConverter(from: input, to: output)
    else { throw ConversionError(description: "no converter from \(input)") }
    // Mix every channel into mono rather than keeping only the first.
    converter.downmix = true
    return converter
  }

  /// Converts one tap buffer. The block form is the one that resamples; the resampler keeps
  /// its own history between calls, so buffer boundaries neither drop nor repeat samples.
  private func convert(
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
      else { throw ConversionError(description: "could not allocate an output buffer") }
      var error: NSError?
      let status = converter.convert(to: output, error: &error) { _, inputStatus in
        guard !supplied else {
          // More will come with the next tap buffer; this is not the end of the stream.
          inputStatus.pointee = .noDataNow
          return nil
        }
        supplied = true
        inputStatus.pointee = .haveData
        return buffer
      }
      if status == .error { throw error ?? ConversionError(description: "conversion failed") }
      // Int16 in memory is little-endian on every Mac this runs on.
      data.append(Data(bytes: output.int16ChannelData![0], count: Int(output.frameLength) * 2))
      // `.haveData` means the output filled before the input was used up; go round again.
      guard status == .haveData else { return data }
    }
  }
}

private struct ConversionError: Error, CustomStringConvertible {
  let description: String
}
