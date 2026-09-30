import Foundation

/// Drives one transcription session over a `WebSocketTransport`.
///
/// Usage is: start `run()` in its own task, feed it audio, then call `finish()`. Audio handed
/// over before the endpoint sends `transcript.created` is held and forwarded the moment it
/// arrives, so the first words of an utterance are not lost to the connection handshake.
///
/// The client keeps the protocol and nothing else. The transcript belongs to whoever reads the
/// events, which in a session is `SessionMachine`.
public actor STTClient {
  private let transport: any WebSocketTransport
  private var isCreated = false
  private var closed = false
  private let ready: AsyncStream<Void>
  private let readyPublisher: AsyncStream<Void>.Continuation
  private var queuedAudio: [Data] = []
  /// The most recently enqueued send. Each new send waits for it before touching the socket,
  /// which is what keeps frames in the order they were handed over while an earlier send is
  /// still suspended inside the transport.
  private var lastSend: Task<Void, any Error>?

  public init(transport: any WebSocketTransport) {
    self.transport = transport
    (ready, readyPublisher) = AsyncStream.makeStream()
  }

  /// Consumes the server stream until `transcript.done` or the socket closing. Throws
  /// `STTError` for an `error` event or a transport failure, and the decoder's error for a frame
  /// that is not decodable JSON. An unrecognised event `type` is ignored instead.
  public func run(observe: @Sendable (STTEvent) async throws -> Bool = { _ in true }) async throws {
    for try await message in transport.messages() {
      guard let event = try STTEvent.decode(message) else { continue }

      try await receive(event)
      if try await !observe(event) { return }
      if case .done = event { return }
    }
  }

  /// Applies each typed event in the single receive loop.
  private func receive(_ event: STTEvent) async throws {
    switch event {
    case .created:
      isCreated = true
      let held = queuedAudio
      queuedAudio.removeAll()
      queuedBytes = 0
      try await sendInOrder { transport in
        for chunk in held { try await transport.send(binary: chunk) }
      }
      readyPublisher.finish()
    case .error(let error): throw STTError.server(error)
    case .done, .partial: break
    }
  }

  /// Five seconds of 16 kHz mono Int16 audio while the handshake completes.
  public static let preHandshakeBytes = 160_000
  private var queuedBytes = 0

  public func close() async {
    closed = true
    readyPublisher.finish()
    transport.close()
    lastSend?.cancel()
    _ = await lastSend?.result
    await transport.waitForClose()
    queuedAudio.removeAll()
    queuedBytes = 0
  }

  /// Hands one chunk of 16 kHz mono Int16 audio to the endpoint, or holds it until the session
  /// is ready.
  public func send(audio: Data) async throws {
    guard !closed else { throw CancellationError() }
    guard isCreated else {
      guard queuedBytes + audio.count <= Self.preHandshakeBytes else {
        throw SessionError.socket("Audio backlog exceeded while connecting")
      }
      queuedBytes += audio.count
      queuedAudio.append(audio)
      return
    }
    try await sendInOrder { try await $0.send(binary: audio) }
  }

  /// Closing follows buffered and live audio. A finishing deadline closes the transport
  /// and releases readiness if the endpoint never accepts the queued first words.
  public func finish() async throws {
    if !isCreated && !queuedAudio.isEmpty {
      for await _ in ready { break }
    }
    guard !closed else { throw CancellationError() }
    try await sendInOrder { transport in
      try await transport.send(text: #"{"type":"finalize"}"#)
      try await transport.send(text: #"{"type":"audio.done"}"#)
    }
  }

  /// Puts one send behind every send already handed over, so that a caller feeding audio from
  /// one task cannot overtake a send suspended in the transport, and `finish()` cannot close
  /// the audio stream ahead of chunks still on their way out.
  ///
  /// A failed send prevents dependent frames from pretending the protocol completed.
  private func sendInOrder(
    _ frames: @Sendable @escaping (any WebSocketTransport) async throws -> Void
  ) async throws {
    let previous = lastSend
    let transport = self.transport
    let send = Task {
      try await previous?.value
      try Task.checkCancellation()
      try await frames(transport)
    }
    lastSend = send
    try await send.value
  }
}
