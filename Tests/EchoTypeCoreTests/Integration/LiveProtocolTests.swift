import EchoTypeCore
import Foundation
import Testing

/// The one test that talks to the real endpoint, so that the streaming protocol is described
/// from observation rather than from the documentation.
///
/// It is skipped unless both a key and a recording are supplied, so the normal test run is
/// unaffected and neither ever needs to be committed:
///
/// ```bash
/// XAI_API_KEY=... ECHOTYPE_FIXTURE_WAV=/path/to/dictation.wav \
///   swift test --disable-xctest 2>&1 | tee ~/echotype-live-session.log
/// ```
///
/// The `tee` path is outside the repository on purpose: the report is long enough to lose to
/// scrollback, and a transcript of real speech must not land in the working tree.
///
/// On the Linux development machine the system libcurl carries no `ws`/`wss` protocol, so
/// `URLSessionWebSocketTask` fails instantly with `NSURLErrorDomain -1002`. A libcurl built
/// with WebSocket support lives in `~/.local/curl-ws`; prefix the command with
/// `LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib` there. On macOS nothing extra is needed.
///
/// The recording wants 15 to 30 seconds of speech containing at least two deliberate pauses of
/// three seconds or more, since the pauses are what make `speech_final` and `endpointing`
/// observable. Audio is paced in real time for the same reason: a recorded silence only reaches
/// the endpoint as silence if it is not sent as part of a burst.
///
/// The evidence is the printed report: every frame the server sent, in order, stamped with
/// wall-clock time and with how much audio had been handed over when it arrived.
enum LiveSession {
  static let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
  static let fixturePath = ProcessInfo.processInfo.environment["ECHOTYPE_FIXTURE_WAV"] ?? ""

  static var isConfigured: Bool { !apiKey.isEmpty && !fixturePath.isEmpty }

  static let requirements: Comment = """
    Set XAI_API_KEY to an xAI key and ECHOTYPE_FIXTURE_WAV to the path of a 16-bit PCM WAV of \
    15 to 30 seconds of speech containing at least two pauses of three seconds or more.
    """

  /// The audio cadence the specification sends from the macOS capture tap.
  static let chunkSeconds = 0.1

  /// Generous enough that a slow handshake or a slow final flush is not mistaken for the
  /// endpoint failing to send the event at all.
  static let createdTimeout = 15.0
  static let doneTimeout = 20.0

  /// How long to keep listening after `transcript.done` for the endpoint to close the socket.
  /// Anything that arrives in this window is exactly the undocumented behaviour worth knowing
  /// about, so the session is not torn down the instant `done` lands.
  static let closeGrace = 3.0
}

@Test(
  "A live streaming session records its full event sequence",
  .enabled(if: LiveSession.isConfigured, LiveSession.requirements)
)
func liveStreamingSessionRecordsItsEventSequence() async throws {
  let recording = try WAVRecording(contentsOf: URL(fileURLWithPath: LiveSession.fixturePath))
  let url = STTConnection.streamingURL(settings: Settings())
  let transport = URLSessionWebSocketTransport(url: url, apiKey: LiveSession.apiKey)
  let log = SessionLog(recording: recording, url: url)

  let receiving = Task {
    do {
      for try await message in transport.messages() {
        await log.record(message)
      }
      await log.noteStreamEnded("the server closed the stream")
    } catch {
      // Teardown below cancels this task, and the harness closing the socket is not the
      // endpoint failing.
      if !Task.isCancelled { await log.recordFailure(error) }
    }
  }

  var failure: (any Error)?
  do {
    try await stream(recording, over: transport, into: log)
  } catch {
    failure = error
  }

  // Read everything before teardown, for the same reason.
  let report = await log.report()
  let outcome = await log.outcome()
  receiving.cancel()
  transport.close()

  // Printed before the expectations so that a failed session still leaves the sequence that
  // explains it.
  print(report)

  if let failure { throw failure }
  #expect(outcome.sawCreated, "transcript.created never arrived. \(outcome.failureDescription)")
  #expect(outcome.partialCount > 0, "no transcript.partial arrived. \(outcome.failureDescription)")
  #expect(outcome.sawDone, "transcript.done never arrived. \(outcome.failureDescription)")
  #expect(
    !outcome.doneArrivedEarly,
    "transcript.done arrived before the client sent audio.done, so the session was cut short"
  )
  #expect(outcome.assembledText.isEmpty == false, "the session assembled no text")
}

/// Waits for the session to be ready, streams the recording in real time, closes the audio
/// stream and waits for the endpoint to finish.
private func stream(
  _ recording: WAVRecording,
  over transport: any WebSocketTransport,
  into log: SessionLog
) async throws {
  await wait(upTo: LiveSession.createdTimeout, until: { await log.isSettled })
  guard await log.hasFailed == false else { return }
  if await log.sawCreated == false {
    // Streaming anyway is what separates an endpoint that waits for audio before saying
    // anything from an endpoint that is simply silent.
    await log.note(
      "transcript.created did not arrive within \(Int(LiveSession.createdTimeout))s; "
        + "streaming the recording anyway"
    )
  }

  var converter = AudioConverter(
    inputSampleRate: recording.sampleRate,
    channelCount: recording.channelCount
  )
  let audioStart = Date()
  for (index, chunk) in recording.chunks(ofSeconds: LiveSession.chunkSeconds).enumerated() {
    guard await log.hasFailed == false else { return }
    try await transport.send(binary: converter.convert(chunk))
    await log.noteAudioSent(seconds: recording.duration(ofInterleaved: chunk))
    let nextChunk = audioStart.addingTimeInterval(Double(index + 1) * LiveSession.chunkSeconds)
    try await sleep(until: nextChunk)
  }

  try await transport.send(text: #"{"type":"finalize"}"#)
  try await transport.send(text: #"{"type":"audio.done"}"#)
  await log.noteAudioStreamClosed()

  await wait(upTo: LiveSession.doneTimeout, until: { await log.isFinished })
  // Keep listening past `done` until the endpoint closes the socket, so anything it sends
  // afterwards is evidence rather than something teardown swallowed.
  await wait(upTo: LiveSession.closeGrace, until: { await log.streamEnded })
}

/// Polls, because the only thing waiting on the stream is the test itself.
private func wait(upTo seconds: Double, until condition: @Sendable () async -> Bool) async {
  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    if await condition() { return }
    try? await Task.sleep(nanoseconds: 50_000_000)
  }
}

private func sleep(until date: Date) async throws {
  let remaining = date.timeIntervalSinceNow
  guard remaining > 0 else { return }
  try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
}

/// The recorded session: every server frame in arrival order, plus the client actions between
/// them, so that cadence and ordering can be read off the report directly.
actor SessionLog {
  /// Everything the expectations need, read in one go before teardown.
  struct Outcome: Sendable {
    var sawCreated = false
    var partialCount = 0
    var sawDone = false
    var doneArrivedEarly = false
    var assembledText = ""
    var failureDescription = ""
  }

  private let recording: WAVRecording
  private let url: URL
  private let start = Date()
  private var lines: [String] = []
  private var assembler = TranscriptAssembler()
  private var audioSeconds = 0.0
  private var transportFailure: (any Error)?
  private var serverError: STTEvent.ServerError?
  private var audioStreamClosed = false
  private var partialCount = 0
  private var doneArrivedEarly = false

  private(set) var sawCreated = false
  private(set) var sawDone = false
  private(set) var streamEnded = false

  init(recording: WAVRecording, url: URL) {
    self.recording = recording
    self.url = url
  }

  /// A dead socket and an `error` event both mean there is nothing left to send.
  var hasFailed: Bool { transportFailure != nil || serverError != nil }

  /// True once there is nothing left to wait for before sending audio.
  var isSettled: Bool { sawCreated || hasFailed }

  /// True once there is nothing left to wait for at all.
  var isFinished: Bool { sawDone || hasFailed }

  func outcome() -> Outcome {
    Outcome(
      sawCreated: sawCreated,
      partialCount: partialCount,
      sawDone: sawDone,
      doneArrivedEarly: doneArrivedEarly,
      assembledText: assembler.text,
      failureDescription: failureDescription
    )
  }

  /// Records one server frame verbatim.
  func record(_ message: String) {
    let event: STTEvent?
    let annotation: String
    do {
      event = try STTEvent.decode(message)
      annotation = event == nil ? "   <-- JSON WITH AN UNDOCUMENTED type" : ""
    } catch {
      event = nil
      // Both of these are undocumented behaviour, but they are different problems: one is a
      // frame the event types cannot read, the other is not JSON at all.
      annotation = isJSON(message) ? "   <-- JSON THE EVENT TYPES REJECTED" : "   <-- NOT JSON"
    }
    lines.append("\(stamp()) \(message)\(annotation)")

    guard let event else { return }
    assembler.apply(event)
    switch event {
    case .created: sawCreated = true
    case .partial: partialCount += 1
    case .error(let error): serverError = error
    case .done:
      sawDone = true
      // A `done` before the client closed the audio stream means the endpoint ended the
      // session on its own terms, and the transcript is whatever it had at that point.
      doneArrivedEarly = doneArrivedEarly || !audioStreamClosed
    }
  }

  func recordFailure(_ error: any Error) {
    transportFailure = error
    noteStreamEnded("stream failed: \(error)")
  }

  func noteStreamEnded(_ text: String) {
    streamEnded = true
    note(text)
  }

  func noteAudioStreamClosed() {
    audioStreamClosed = true
    note("sent finalize then audio.done")
  }

  func note(_ text: String) {
    lines.append("\(stamp()) -- \(text)")
  }

  func noteAudioSent(seconds: Double) {
    audioSeconds += seconds
  }

  /// The artefact: everything a reader needs to answer the workstream's questions.
  func report() -> String {
    """

    ===== Live xAI streaming session =====
    Recording: \(recording.summary)
    Connection: \(url.absoluteString)
    Columns: [wall clock since connect | audio handed over so far]

    \(lines.joined(separator: "\n"))

    Events: \(partialCount) transcript.partial, created=\(sawCreated), done=\(sawDone)\
    \(doneArrivedEarly ? " (before the client sent audio.done)" : "")
    Failure: \(failureDescription)
    Assembled text: \(assembler.text)
    ======================================

    """
  }

  private var failureDescription: String {
    let reported = [
      serverError.map { "Server error \($0.code ?? "with no code"): \($0.message)." },
      transportFailure.map { "Stream failure: \($0)." },
    ].compactMap { $0 }
    return reported.isEmpty ? "None reported." : reported.joined(separator: " ")
  }

  private func stamp() -> String {
    let elapsed = Date().timeIntervalSince(start)
    return String(format: "[%6.2fs | audio %6.2fs]", elapsed, audioSeconds)
  }

  private func isJSON(_ message: String) -> Bool {
    let data = Data(message.utf8)
    return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
  }
}
