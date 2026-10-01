@testable import EchoTypeCore
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct StreamingResponseTests {
  @Test func largeResponseCallbackDeliversBoundedChunksInOrder() async throws {
    let body = SilentResponse()
    let data = Data((0..<(StreamingResponse.maximumBufferedBytes * 3 + 17)).map { UInt8($0 % 251) })
    let producer = Task.detached { body.receive(data); body.complete() }
    var received = Data()
    while let chunk = try await body.response.next() {
      #expect(chunk.count <= StreamingResponse.chunkBytes)
      received.append(chunk)
    }
    await producer.value
    #expect(received == data)
  }

  @Test func cancelReleasesResponseCallbackWaitingForQueueCapacity() async {
    let body = SilentResponse()
    body.receive(Data(repeating: 0, count: StreamingResponse.maximumBufferedBytes))
    let entered = Gate()
    let producer = Task.detached { entered.open(); body.receive(Data([1])) }
    await entered.wait()
    body.response.cancel()
    await producer.value
    do { _ = try await body.response.next(); Issue.record("Cancel retained queued bytes") }
    catch is CancellationError {} catch { Issue.record(error) }
  }

  @Test func responseQueuePreservesChunksAndEOF() async throws {
    let body = SilentResponse()
    body.receive(Data([1])); body.receive(Data([2, 3])); body.complete()
    #expect(try await body.response.next() == Data([1]))
    #expect(try await body.response.next() == Data([2, 3]))
    #expect(try await body.response.next() == nil)
  }

  @Test func failedStatusThrowsTheProviderMappingAndNetworkFailuresPropagate() async {
    let mapped = SilentResponse(errorForStatus: { _ in .rateLimited })
    mapped.receive(status: 429)
    do { _ = try await mapped.response.next(); Issue.record("Failed status succeeded") }
    catch { #expect(error as? ProviderError == .rateLimited) }

    for code: URLError.Code in [.networkConnectionLost, .timedOut] {
      let failed = SilentResponse()
      failed.complete(URLError(code))
      do { _ = try await failed.response.next(); Issue.record("Network failure succeeded") }
      catch { #expect((error as? URLError)?.code == code) }
    }
  }

  @Test func cancellingAnEmptyResponseQueueResolvesItsAwait() async {
    let body = SilentResponse()
    let next = Task { try await body.response.next() }
    next.cancel()
    do { _ = try await next.value; Issue.record("Cancelled request succeeded") }
    catch is CancellationError {} catch { Issue.record(error) }
  }
}

/// Opens once, releasing every waiter.
private final class Gate: Sendable {
  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation
  init() { (stream, continuation) = AsyncStream.makeStream() }
  func wait() async { for await _ in stream { break } }
  func open() { continuation.finish() }
}
