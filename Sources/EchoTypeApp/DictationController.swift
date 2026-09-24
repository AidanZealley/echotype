import EchoTypeCore
import Foundation
import Observation

/// Owns the session lifecycle: the hotkey opens a session, the hotkey again commits it, Escape
/// discards it, and the outcome is inserted at the caret.
///
/// `state` and `problem` are what the menu bar renders. The menu is the only place the user can
/// see anything in this milestone, so it also carries failures and a missing API key.
@MainActor @Observable final class DictationController {
  private(set) var state: SessionMachine.State = .idle
  /// Why the last attempt failed, until the next one starts.
  private(set) var problem: String?

  private enum Phase {
    case idle
    /// Opening the microphone and reading the key, which takes a noticeable moment every
    /// session. Presses in the meantime are ignored, and Escape passes through to the focused
    /// app because no session is open yet.
    case starting
    case running(SessionMachine)
  }

  /// No persistence yet: the defaults are the settings.
  private let settings = Settings()
  private let audio = AudioCapture()
  private let inserter = Inserter()
  private var phase = Phase.idle
  private var monitor: HotkeyMonitor?

  init() {
    let monitor = HotkeyMonitor(
      hotkey: settings.hotkey,
      onHotkey: { [weak self] in self?.hotkeyPressed() },
      onEscape: { [weak self] in self?.escapePressed() ?? false }
    )
    monitor.start()
    self.monitor = monitor
  }

  private func hotkeyPressed() {
    switch phase {
    case .idle:
      phase = .starting
      Task { await dictate() }
    case .starting:
      break
    case .running:
      // Commit by ending capture rather than triggering the session here. The pump sends what
      // is still queued and the partial last chunk `stop()` flushes, then triggers, so the last
      // word reaches xAI before `audio.done`.
      audio.stop()
    }
  }

  /// Escape belongs to the focused app unless a session is open.
  private func escapePressed() -> Bool {
    guard case .running(let session) = phase else { return false }
    Task { await session.cancel() }
    return true
  }

  /// One session, from the first press to the insertion.
  private func dictate() async {
    problem = nil
    defer { phase = .idle }

    // The microphone first: before the socket, so a denied grant never opens a billed
    // connection, and before the key, so the Keychain read is not in the first word's path
    // and the first press raises the Microphone prompt even with no key seeded. Chunks buffer
    // in the stream until the session accepts them.
    let chunks: AsyncThrowingStream<Data, any Error>
    do {
      chunks = try await audio.start()
    } catch {
      problem = describe(error)
      return
    }
    guard let apiKey = await Task.detached(operation: { Keychain.apiKey() }).value else {
      audio.stop()
      problem = "No xAI API key in the Keychain"
      return
    }
    // The socket opens here, on trigger, because an idle open socket bills streaming time.
    let transport = URLSessionWebSocketTransport(
      url: STTConnection.streamingURL(settings: settings), apiKey: apiKey)
    let session = SessionMachine(transport: transport, settings: settings, clock: SystemClock())
    phase = .running(session)

    let (outcome, audioFailure) = await run(session, streaming: chunks)
    state = .idle
    finish(outcome, audioFailure: audioFailure)
  }

  /// Runs the session to its outcome, mirroring its state into the menu and feeding it audio.
  /// Returns the error that ended capture early, if the microphone failed.
  private func run(
    _ session: SessionMachine, streaming chunks: AsyncThrowingStream<Data, any Error>
  ) async -> (SessionMachine.Outcome, (any Error)?) {
    let outcome = Task { await session.run() }
    var pump: Task<(any Error)?, Never>?
    for await snapshot in session.snapshots {
      state = snapshot.state
      // The first snapshot is `listening`, from which point `send(audio:)` accepts audio rather
      // than dropping it.
      if pump == nil { pump = Task { await self.pump(chunks, into: session) } }
    }
    let result = await outcome.value
    // Ends the stream, which ends the pump, and releases the microphone.
    // A session that ended on its own (cancel, silence, the hard cap, a failure) still has a
    // stream open. After a commit press this is a second `stop()`, which does nothing.
    audio.stop()
    return (result, await pump?.value ?? nil)
  }

  /// Feeds the session every chunk the stream yields, then commits it. The stream ends on
  /// `stop()`, from a commit press or the end of the session, or by throwing if the microphone
  /// fails. Returns that failure, if any.
  private func pump(
    _ chunks: AsyncThrowingStream<Data, any Error>, into session: SessionMachine
  ) async -> (any Error)? {
    var failure: (any Error)?
    do {
      for try await chunk in chunks {
        // A failed send means the socket failed, and the session reports that itself. Keep
        // draining, so the pump only ever ends with the stream and the trigger below.
        try? await session.send(audio: chunk)
      }
    } catch {
      // The microphone failed mid-session. Commit what was heard rather than lose it, and
      // report why it stopped.
      failure = error
    }
    // Does nothing if the session has already ended.
    await session.trigger()
    return failure
  }

  private func finish(_ outcome: SessionMachine.Outcome, audioFailure: (any Error)?) {
    switch outcome {
    case .insert(let text):
      inserter.insert(text)
    case .nothing:
      break
    case .failed(let text, let error):
      if !text.isEmpty { inserter.insert(text) }
      problem = describe(error)
    }
    if let audioFailure { problem = describe(audioFailure) }
  }

  private func describe(_ error: any Error) -> String {
    switch error {
    case AudioCapture.Failure.microphoneDenied:
      "Microphone access is off. Allow it in System Settings > Privacy & Security > Microphone"
    case AudioCapture.Failure.noInputDevice:
      "No microphone found"
    case AudioCapture.Failure.engineFailed(let underlying):
      "Microphone failed: \(underlying.localizedDescription)"
    // A wrong key is a 400 from api.x.ai, and 401 means no key reached it at all.
    case SessionError.stt(.badRequest), SessionError.stt(.unauthorized):
      "xAI rejected the API key"
    case SessionError.stt(.rateLimited):
      "xAI rate limit reached"
    case SessionError.stt(.unavailable):
      "xAI is unavailable"
    case SessionError.stt(.server(let serverError)):
      "xAI error: \(serverError.message)"
    case SessionError.socket(let description):
      "Connection failed: \(description)"
    default:
      "Dictation failed: \(error)"
    }
  }
}
