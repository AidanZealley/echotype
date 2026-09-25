import AVFoundation

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
    let chunker = AudioChunker(continuation) { [weak self] level in self?.onLevel(level) }
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
  let chunker: AudioChunker
  /// The open device, nil while closed.
  var microphone: Microphone?
  /// Whether the device has been lost and reopened once already.
  var reopened = false

  init(deviceUID: String?, chunker: AudioChunker) {
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
    _ deviceUID: String?, delivering chunker: AudioChunker,
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
