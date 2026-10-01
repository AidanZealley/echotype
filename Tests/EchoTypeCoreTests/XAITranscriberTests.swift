@testable import EchoTypeCore
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct XAITranscriberTests {
  let transport = FakeWebSocketTransport()
  let transcriber: XAI.Transcriber

  init() {
    transcriber = XAI.Transcriber(transport: transport)
  }

  /// Every event until the stream ends, and the error it ended with, if any.
  private func events() async -> (events: [TranscriptionEvent], error: (any Error)?) {
    var events: [TranscriptionEvent] = []
    do {
      for try await event in transcriber.events { events.append(event) }
      return (events, nil)
    } catch {
      return (events, error)
    }
  }

  @Test("Server events translate into neutral events")
  func translationTable() async {
    transport.emit(Fixture.created)
    transport.emit(Fixture.partial("tan stock"))
    // Empty partials arrive at about 1 Hz through a silence and are not speech.
    transport.emit(Fixture.partial(""))
    transport.emit(Fixture.partial("tanstack is great", isFinal: true, speechFinal: true))
    // The end of an utterance is speech even without text.
    transport.emit(Fixture.partial("", speechFinal: true))
    // `finalize` can settle the tail without `speech_final`; `transcript.done` commits it.
    transport.emit(Fixture.partial("and more", isFinal: true))
    transport.emit(Fixture.done)
    transport.emit(Fixture.partial("after the end"))

    let committed = "tanstack is great"
    let (events, error) = await events()
    #expect(error == nil)
    #expect(
      events == [
        .ready,
        .transcript(.init(provisional: "tan stock")), .speech,
        .transcript(.init()),
        .transcript(.init(committed: committed)), .speech,
        .transcript(.init(committed: committed)), .speech,
        .transcript(.init(committed: committed, utterance: "and more")), .speech,
        .transcript(.init(committed: "\(committed) and more")), .finished,
      ])
  }

  @Test("finish() sends finalize then audio.done after the audio")
  func finishSendsTheClosingMessages() async throws {
    try await transcriber.send(audio: Data([1, 2]))
    try await transcriber.finish()
    #expect(transport.binaryFrames == [Data([1, 2])])
    #expect(transport.textFrames == [#"{"type":"finalize"}"#, #"{"type":"audio.done"}"#])
  }

  @Test("An error event ends the events with the server's message")
  func errorEventThrowsProviderError() async {
    transport.emit(Fixture.created)
    transport.emit(Fixture.error(code: "internal_error", message: "something broke"))
    let (events, error) = await events()
    #expect(events == [.ready])
    #expect(error as? ProviderError == .failed("something broke"))
  }

  @Test("A transport failure surfaces unchanged")
  func transportFailureSurfaces() async {
    transport.emit(Fixture.created)
    transport.fail(with: ProviderError.rejectedCredential)
    let (events, error) = await events()
    #expect(events == [.ready])
    #expect(error as? ProviderError == .rejectedCredential)
  }

  @Test("A frame that is not JSON ends the events rather than truncating in silence")
  func undecodableFrameThrows() async {
    transport.emit(Fixture.created)
    transport.emit("{not json")
    transport.emit(Fixture.partial("second sentence", speechFinal: true))
    let (events, error) = await events()
    #expect(events == [.ready])
    #expect(error != nil && !(error is ProviderError))
  }

  @Test("close() ends the events")
  func closeEndsTheEvents() async {
    transcriber.close()
    await transcriber.waitForClose()
    let (events, error) = await events()
    #expect(events.isEmpty && error == nil)
  }

  @Test(
    "Failed statuses map through the shared default, with 400 as a rejected key",
    arguments: [
      (400, ProviderError.rejectedCredential), (401, .rejectedCredential), (403, .rejectedCredential),
      (429, .rateLimited), (500, .unavailable), (503, .unavailable), (413, .failed("HTTP 413")),
    ])
  func statusMapping(status: Int, expected: ProviderError) {
    #expect(XAI.error(httpStatus: status) == expected)
    if status != 400 { #expect(ProviderError(httpStatus: status) == expected) }
  }

  @Test("The default mapping does not treat 400 as a rejected key")
  func defaultMappingOf400() {
    #expect(ProviderError(httpStatus: 400) == .failed("HTTP 400"))
  }

  // MARK: Connection

  private func queryItems(_ request: TranscriptionRequest) -> [URLQueryItem] {
    let url = XAI.Transcriber.streamingURL(for: request)
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
  }

  @Test("The connection URL carries the documented parameters")
  func connectionURLCarriesTheDocumentedParameters() {
    let request = TranscriptionRequest(language: "en-GB", keyterms: ["EchoType"], credential: nil)
    let url = XAI.Transcriber.streamingURL(for: request)

    #expect(url.scheme == "wss")
    #expect(url.host == "api.x.ai")
    #expect(url.path == "/v1/stt")
    #expect(
      queryItems(request) == [
        URLQueryItem(name: "encoding", value: "pcm"),
        URLQueryItem(name: "sample_rate", value: "16000"),
        URLQueryItem(name: "interim_results", value: "true"),
        URLQueryItem(name: "endpointing", value: "1200"),
        URLQueryItem(name: "filler_words", value: "false"),
        URLQueryItem(name: "format", value: "true"),
        URLQueryItem(name: "language", value: "en-GB"),
        URLQueryItem(name: "keyterm", value: "EchoType"),
      ]
    )
  }

  @Test("Keyterms are percent encoded and cut to 50 characters")
  func keytermsInTheURL() {
    let long = String(repeating: "x", count: 60)
    let request = TranscriptionRequest(
      language: "en", keyterms: ["TanStack Start", "pnpm", long], credential: nil)

    #expect(
      XAI.Transcriber.streamingURL(for: request).absoluteString
        .contains("&keyterm=TanStack%20Start&keyterm=pnpm&"))
    #expect(queryItems(request).last?.value == String(repeating: "x", count: 50))
  }

  @Test("The API key travels as a bearer token")
  func apiKeyIsABearerToken() {
    let request = TranscriptionRequest(language: "en", keyterms: [], credential: "xai-123")
    #expect(
      XAI.Transcriber.urlRequest(for: request).value(forHTTPHeaderField: "Authorization")
        == "Bearer xai-123")
  }
}
