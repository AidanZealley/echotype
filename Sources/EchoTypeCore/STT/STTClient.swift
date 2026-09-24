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
  private var queuedAudio: [Data] = []
  /// The most recently enqueued send. Each new send waits for it before touching the socket,
  /// which is what keeps frames in the order they were handed over while an earlier send is
  /// still suspended inside the transport.
  private var lastSend: Task<Void, any Error>?

  public init(transport: any WebSocketTransport) {
    self.transport = transport
  }

  /// Consumes the server stream until `transcript.done` or the socket closing. Throws
  /// `STTError` for an `error` event or a transport failure, and the decoder's error for a frame
  /// that is not decodable JSON. An unrecognised event `type` is ignored instead.
  public func run() async throws {
    for try await message in transport.messages() {
      guard let event = try STTEvent.decode(message) else { continue }

      switch event {
      case .created:
        isCreated = true
        let held = queuedAudio
        queuedAudio.removeAll()
        try await sendInOrder { transport in
          for chunk in held {
            try await transport.send(binary: chunk)
          }
        }
      case .error(let error):
        throw STTError.server(error)
      case .done:
        return
      case .partial:
        break
      }
    }
  }

  /// Hands one chunk of 16 kHz mono Int16 audio to the endpoint, or holds it until the session
  /// is ready.
  public func send(audio: Data) async throws {
    guard isCreated else {
      queuedAudio.append(audio)
      return
    }
    try await sendInOrder { try await $0.send(binary: audio) }
  }

  /// Forces finalisation and signals the end of audio. `transcript.done` follows.
  ///
  /// If `transcript.created` never arrived there is no session to send the held audio to, so it
  /// is dropped and only the closing messages go out.
  public func finish() async throws {
    // Audio still held here means `transcript.created` never arrived, so there is no session
    // to send it to.
    queuedAudio.removeAll()
    try await sendInOrder { transport in
      try await transport.send(text: #"{"type":"finalize"}"#)
      try await transport.send(text: #"{"type":"audio.done"}"#)
    }
  }

  /// Puts one send behind every send already handed over, so that a caller feeding audio from
  /// one task cannot overtake a send suspended in the transport, and `finish()` cannot close
  /// the audio stream ahead of chunks still on their way out.
  ///
  /// A failed send does not stop the ones behind it; each caller sees its own error.
  private func sendInOrder(
    _ frames: @Sendable @escaping (any WebSocketTransport) async throws -> Void
  ) async throws {
    let previous = lastSend
    let transport = self.transport
    let send = Task {
      _ = await previous?.result
      try await frames(transport)
    }
    lastSend = send
    try await send.value
  }
}
