import EchoTypeCore
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct STTClientTests {
  @Test("No audio is sent before transcript.created arrives")
  func audioWaitsForTheSessionToBeReady() async throws {
    let transport = FakeWebSocketTransport()
    let client = STTClient(transport: transport)

    let firstWords = Data([0x01, 0x02])
    try await client.send(audio: firstWords)
    #expect(transport.binaryFrames.isEmpty)

    transport.emit(Fixture.created)
    transport.emit(Fixture.partial("hello", speechFinal: true))
    transport.emit(Fixture.done)
    try await client.run()

    // Held rather than dropped, so the handshake does not clip the first word.
    #expect(transport.binaryFrames == [firstWords])

    let laterWords = Data([0x03])
    try await client.send(audio: laterWords)
    #expect(transport.binaryFrames == [firstWords, laterWords])
  }

  @Test("Stopping before readiness retains queued audio ahead of closure")
  func finishBeforeTheSessionIsReady() async throws {
    let transport = FakeWebSocketTransport()
    defer { transport.close() }
    let client = STTClient(transport: transport)
    try await client.send(audio: Data([1, 2]))
    let finish = await client.startFinishing()
    #expect(transport.textFrames.isEmpty)
    transport.emit(Fixture.created)
    transport.emit(Fixture.done)
    try await client.run()
    try await finish.value
    #expect(transport.binaryFrames == [Data([1, 2])])
    #expect(transport.textFrames == [#"{"type":"finalize"}"#, #"{"type":"audio.done"}"#])
  }

  @Test("Audio handed over during the flush stays behind what was already queued")
  func queuedAudioKeepsItsOrderWhileASendIsInFlight() async throws {
    let transport = BlockingWebSocketTransport()
    defer { transport.close() }
    let client = STTClient(transport: transport)

    let firstChunk = Data([0x0A])
    let secondChunk = Data([0x0B])
    try await client.send(audio: firstChunk)
    transport.emit(Fixture.created)
    let session = Task { try await client.run() }
    defer { session.cancel() }

    // The flush is now suspended inside the transport, which is exactly when the capture layer
    // hands over its next chunk. `send(audio:)` returns only once its own chunk is on the wire,
    // so the handover comes from its own task, as capture does.
    await transport.waitForFirstSend()
    let handover = await client.startSending(audio: secondChunk)
    await transport.releaseFirstSend()
    try await handover.value

    transport.emit(Fixture.done)
    try await session.value

    #expect(await transport.binaryFrames == [firstChunk, secondChunk])
  }

  @Test("Finishing closes the audio stream behind audio still on its way out")
  func finishWaitsForAudioAlreadyHandedOver() async throws {
    let transport = BlockingWebSocketTransport()
    defer { transport.close() }
    let client = STTClient(transport: transport)

    try await client.send(audio: Data([0x0A]))
    transport.emit(Fixture.created)
    let session = Task { try await client.run() }
    defer { session.cancel() }

    // The hotkey is released while the capture layer's chunk is still in the transport, which is
    // how capture and stopping interact: audio from one task, `finish()` from another.
    await transport.waitForFirstSend()
    let stop = await client.startFinishing()
    await transport.releaseFirstSend()
    try await stop.value

    // `audio.done` after the audio, never before it, or the last words are sent past the end of
    // the stream.
    #expect(
      await transport.frameLog == ["audio", #"{"type":"finalize"}"#, #"{"type":"audio.done"}"#])

    transport.emit(Fixture.done)
    try await session.value
  }

  @Test("An error event ends the session with a typed error")
  func errorEventSurfacesAsATypedError() async throws {
    let transport = FakeWebSocketTransport()
    let client = STTClient(transport: transport)

    transport.emit(Fixture.created)
    transport.emit(Fixture.partial("kept text", speechFinal: true))
    transport.emit(Fixture.error(code: "internal_error", message: "something broke"))

    await #expect(throws: STTError.server(.init(code: "internal_error", message: "something broke")))
    {
      try await client.run()
    }
  }

  @Test("A transport failure surfaces unchanged")
  func transportFailureSurfaces() async throws {
    let transport = FakeWebSocketTransport()
    let client = STTClient(transport: transport)

    transport.emit(Fixture.created)
    transport.emit(Fixture.partial("half a sentence", speechFinal: true))
    transport.fail(with: STTError.unavailable)

    await #expect(throws: STTError.unavailable) {
      try await client.run()
    }
  }

  @Test("Buffered send failure propagates and prevents closing frames")
  func bufferedSendFailure() async throws {
    let transport = FailedBinaryTransport()
    let client = STTClient(transport: transport)
    try await client.send(audio: Data([1]))
    transport.base.emit(Fixture.created)
    await #expect(throws: STTError.unavailable) { try await client.run() }
    await #expect(throws: STTError.unavailable) { try await client.finish() }
    #expect(transport.base.textFrames.isEmpty)
    await client.close()
  }

  @Test("Each documented error status maps to a distinguishable error")
  func documentedStatusesMapToDistinctErrors() {
    #expect(STTError(httpStatus: 400) == .badRequest)
    #expect(STTError(httpStatus: 401) == .unauthorized)
    #expect(STTError(httpStatus: 413) == .payloadTooLarge)
    #expect(STTError(httpStatus: 429) == .rateLimited)
    #expect(STTError(httpStatus: 502) == .downloadFailed)
    #expect(STTError(httpStatus: 503) == .unavailable)
    #expect(STTError(httpStatus: 418) == .unexpectedStatus(418))
  }
}

private extension STTClient {
  // Immediate tasks run on this actor until suspension. Returning the task therefore proves
  // the send was enqueued behind the blocked flush, before the test releases the transport.
  func startSending(audio: Data) -> Task<Void, any Error> {
    Task.immediate { try await self.send(audio: audio) }
  }

  func startFinishing() -> Task<Void, any Error> {
    Task.immediate { try await self.finish() }
  }
}

private struct FailedBinaryTransport: WebSocketTransport {
  let base = FakeWebSocketTransport()
  func send(binary: Data) async throws { throw STTError.unavailable }
  func send(text: String) async throws { try await base.send(text: text) }
  func messages() -> AsyncThrowingStream<String, any Error> { base.messages() }
  func close() { base.close() }
}
