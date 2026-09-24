import EchoTypeCore
import Foundation
import Testing

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

@Test("Stopping before transcript.created still closes the session and sends no audio")
func finishBeforeTheSessionIsReady() async throws {
  let transport = FakeWebSocketTransport()
  let client = STTClient(transport: transport)

  try await client.send(audio: Data([0x01, 0x02]))
  try await client.finish()

  #expect(transport.textFrames == [#"{"type":"finalize"}"#, #"{"type":"audio.done"}"#])
  #expect(transport.binaryFrames.isEmpty)

  // The held audio is gone rather than replayed, so a late `created` cannot send speech the
  // user already stopped.
  transport.emit(Fixture.created)
  transport.endStream()
  try await client.run()
  #expect(transport.binaryFrames.isEmpty)
}

@Test("Audio handed over during the flush stays behind what was already queued")
func queuedAudioKeepsItsOrderWhileASendIsInFlight() async throws {
  let transport = BlockingWebSocketTransport()
  let client = STTClient(transport: transport)

  let firstChunk = Data([0x0A])
  let secondChunk = Data([0x0B])
  try await client.send(audio: firstChunk)
  transport.emit(Fixture.created)
  let session = Task { try await client.run() }

  // The flush is now suspended inside the transport, which is exactly when the capture layer
  // hands over its next chunk. `send(audio:)` returns only once its own chunk is on the wire,
  // so the handover comes from its own task, the way workstream 4 will drive this.
  await transport.waitForFirstSend()
  let handover = Task { try await client.send(audio: secondChunk) }
  for _ in 0..<10 { await Task.yield() }
  await transport.releaseFirstSend()
  try await handover.value

  transport.emit(Fixture.done)
  try await session.value

  #expect(await transport.binaryFrames == [firstChunk, secondChunk])
}

@Test("Finishing closes the audio stream behind audio still on its way out")
func finishWaitsForAudioAlreadyHandedOver() async throws {
  let transport = BlockingWebSocketTransport()
  let client = STTClient(transport: transport)

  try await client.send(audio: Data([0x0A]))
  transport.emit(Fixture.created)
  let session = Task { try await client.run() }

  // The hotkey is released while the capture layer's chunk is still in the transport, which is
  // how workstream 4 will drive this: audio from one task, `finish()` from another.
  await transport.waitForFirstSend()
  let stop = Task { try await client.finish() }
  for _ in 0..<10 { await Task.yield() }
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
