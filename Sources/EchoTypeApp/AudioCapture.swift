import AVFoundation
import EchoTypeCore
import Synchronization

/// The microphone, as a dictation session needs it: 16 kHz mono little-endian Int16, in chunks
/// of roughly 100ms, ready for `SessionMachine.send(audio:)`.
///
/// The device is held only while a session is listening, so the macOS microphone indicator
/// clears as soon as the session ends. `start(deviceUID:)` opens the device and starts
/// delivering; `stop()` ends delivery and closes it. Every session pays the 100 to 300ms device
/// open before audio flows.
///
/// Each session names the input it wants by unique ID, or `nil` for the system default. The
/// session opens that input when it is connected and the system default otherwise, and keeps
/// it: a change of system default mid-session is not followed. If the device in use goes away,
/// a session in progress reopens once, choosing again the same way. A second loss in the same
/// session ends its stream with the error, so a failure that recurs on every open cannot loop.
///
/// Capture is an input-only `AVCaptureSession` rather than `AVAudioEngine`. The engine ties
/// input to an output-side IO unit and stops itself on any device format change, and opening a
/// Bluetooth headset's microphone switches its profile and so its format on every open: with
/// the engine, every open stopped and reopened again about once a second. Audio arrives in
/// whatever format the device has at the moment, and the converter follows it.
@MainActor final class AudioCapture {
  enum Failure: Error {
    /// The user refused microphone access, now or earlier. Only System Settings can undo it.
    case microphoneDenied
    /// There is no input device to open.
    case noInputDevice
    /// The capture session would not start or failed while running, or audio could not be
    /// converted.
    case captureFailed(any Error)
  }

  /// Called on the main actor with the input level, from 0 to 1 for the overlay's meter, on the
  /// first audio after `start(deviceUID:)` and then once per chunk, so roughly every 100ms. The
  /// first call means audio is flowing.
  var onLevel: @MainActor (Double) -> Void = { _ in }

  /// The session in progress, nil between sessions.
  private var session: Session?

  /// Opens the input with unique ID `deviceUID`, or the system default if that is `nil` or not
  /// connected, and starts delivering chunks.
  ///
  /// The stream yields chunks in capture order and finishes when `stop()` is called. It throws
  /// `Failure.captureFailed` if the device is lost mid-session and cannot be reopened, is lost
  /// a second time, or if conversion fails. Starting again finishes the previous stream.
  func start(deviceUID: String?) async throws(Failure) -> AsyncThrowingStream<Data, any Error> {
    stop()
    let (stream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
    let chunker = Chunker(continuation) { [weak self] level in self?.onLevel(level) }
    let session = Session(deviceUID: deviceUID, chunker: chunker)
    self.session = session
    do {
      try await open(session)
    } catch {
      end(session)
      throw error
    }
    return stream
  }

  /// Stops delivering, sends whatever is left of the last chunk, finishes the stream and
  /// closes the device. Calling it again does nothing.
  func stop() {
    guard let session else { return }
    end(session)
  }

  /// Asks for microphone access the first time, then opens the session's input, unless the
  /// session has ended meanwhile.
  private func open(_ session: Session) async throws(Failure) {
    guard await AVCaptureDevice.requestAccess(for: .audio) else { throw .microphoneDenied }
    guard session === self.session else { return }
    // Kept before the open finishes, so ending the session meanwhile closes it once it has
    // opened: the close queues behind the open on the microphone's executor.
    let microphone = Microphone()
    session.microphone = microphone
    try await microphone.open(session.deviceUID, delivering: session.chunker) {
      [weak self, weak session, weak microphone] error in
      Task { @MainActor in
        if let session, let microphone { self?.deviceLost(microphone, of: session, error) }
      }
    }
  }

  /// The device in use went away or the capture session failed. Reopen once, on the chosen
  /// input if it is still connected and the default otherwise.
  private func deviceLost(_ lost: Microphone, of session: Session, _ error: any Error) {
    // Only the open in use by the session in progress. A report from an ended session, or from
    // an open already replaced, such as the second of the two notifications a disconnect may
    // post, is ignored.
    guard session === self.session, lost === session.microphone else { return }
    session.closeMicrophone()
    guard !session.reopened else { return end(session, throwing: Failure.captureFailed(error)) }
    session.reopened = true
    Task {
      do {
        try await open(session)
      } catch {
        end(session, throwing: error)
      }
    }
  }

  /// Ends `session` if it is still the one in progress, and does nothing otherwise.
  private func end(_ session: Session, throwing error: (any Error)? = nil) {
    guard session === self.session else { return }
    self.session = nil
    session.chunker.end(throwing: error)
    session.closeMicrophone()
  }
}

/// One session's capture. Everything a session owns is here rather than on `AudioCapture`, so an
/// open or reopen still in flight when its session ends can only reach its own session: it
/// checks that its session is still the one in progress, and the device it opens delivers to
/// its own session's chunker, which drops audio once that session has ended. Neither can reach
/// the next session's microphone or stream.
@MainActor private final class Session {
  /// The chosen input, kept so a reopen chooses the same way.
  let deviceUID: String?
  let chunker: Chunker
  /// The open device, nil while closed.
  var microphone: Microphone?
  /// Whether the device has been lost and reopened once already.
  var reopened = false

  init(deviceUID: String?, chunker: Chunker) {
    self.deviceUID = deviceUID
    self.chunker = chunker
  }

  func closeMicrophone() {
    guard let microphone else { return }
    self.microphone = nil
    Task { await microphone.close() }
  }
}

/// One open of the input device: an input-only `AVCaptureSession` feeding the chunker.
///
/// Starting and stopping a capture session block until done, so they run on this actor's own
/// serial queue, never on the main actor, where the event tap runs, or in the shared pool. The
/// actor is also what lets the session, which is not `Sendable`, be reached from the main
/// actor.
private actor Microphone {
  private let queue = DispatchSerialQueue(label: "EchoType.microphone")
  nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

  private var session: AVCaptureSession?
  private var observers: [any NSObjectProtocol] = []

  /// Opens the input with unique ID `deviceUID` if it is connected, and the system default
  /// otherwise, and starts it delivering sample buffers to `chunker`. Calls `onLost`, on any
  /// thread, if the device goes away or the session fails while open.
  func open(
    _ deviceUID: String?, delivering chunker: Chunker,
    onLost: @escaping @Sendable (any Error) -> Void
  ) throws(AudioCapture.Failure) {
    guard let device = Self.device(deviceUID) else { throw .noInputDevice }
    let input: AVCaptureDeviceInput
    do {
      input = try AVCaptureDeviceInput(device: device)
    } catch {
      throw .captureFailed(error)
    }
    // No `audioSettings`: the output vends the device's native format, whatever that is at
    // the moment, and the chunker converts it. Settings the output cannot honour raise.
    let output = AVCaptureAudioDataOutput()
    // Samples on a queue of their own, so they never wait on a start or stop here.
    output.setSampleBufferDelegate(chunker, queue: DispatchQueue(label: "EchoType.samples"))
    let session = AVCaptureSession()
    // `addInput` and `addOutput` raise rather than fail when these say no.
    guard session.canAddInput(input) else {
      throw .captureFailed(CaptureError("cannot capture from \(device.localizedName)"))
    }
    session.addInput(input)
    guard session.canAddOutput(output) else {
      throw .captureFailed(CaptureError("cannot read audio from \(device.localizedName)"))
    }
    session.addOutput(output)

    self.session = session
    // Reports a failure to start through the runtime error notification rather than throwing.
    session.startRunning()
    observers = Self.observe(device, session, onLost: onLost)
    // Checked after observing, so a stop in between is caught here or by an observer.
    guard session.isRunning else {
      close()
      throw .captureFailed(CaptureError("\(device.localizedName) did not start"))
    }
  }

  func close() {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers = []
    session?.stopRunning()
    session = nil
  }

  /// The chosen input if it is connected, else the system default.
  private static func device(_ uniqueID: String?) -> AVCaptureDevice? {
    if let uniqueID, let chosen = AVCaptureDevice(uniqueID: uniqueID), chosen.isConnected {
      return chosen
    }
    return AVCaptureDevice.default(for: .audio)
  }

  /// Watches for the two ways an open device stops delivering: the device is disconnected
  /// (unplugged, or Bluetooth out of range), or the session hits a runtime error. Which of
  /// them a disconnect posts is not documented for macOS, so both are watched; the capture
  /// ignores whichever arrives second. A change of the device's format, such as a Bluetooth
  /// profile switch, posts neither: the output carries on in the new format.
  private static func observe(
    _ device: AVCaptureDevice, _ session: AVCaptureSession,
    onLost: @escaping @Sendable (any Error) -> Void
  ) -> [any NSObjectProtocol] {
    let center = NotificationCenter.default
    let name = device.localizedName
    return [
      center.addObserver(
        forName: AVCaptureDevice.wasDisconnectedNotification, object: device, queue: nil
      ) { _ in onLost(CaptureError("\(name) was disconnected")) },
      center.addObserver(
        forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
      ) { notification in
        onLost(
          notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            ?? CaptureError("\(name) stopped"))
      },
    ]
  }
}

/// Converts what the device delivers and cuts it into one session's chunks.
///
/// The capture output calls it on its sample queue while the main actor ends it, so all of it
/// happens under one lock. That also orders the end: nothing captured after `end` is delivered.
/// Each session has its own, so a device still closing after its session ended feeds a chunker
/// that drops what it hears, never the next session's stream.
private final class Chunker: NSObject, Sendable, AVCaptureAudioDataOutputSampleBufferDelegate {
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
private struct CaptureError: LocalizedError {
  let errorDescription: String?
  init(_ description: String) { errorDescription = description }
}
