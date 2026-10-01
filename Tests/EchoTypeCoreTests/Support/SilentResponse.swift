@testable import EchoTypeCore
import Foundation

/// A `StreamingResponse` held open without a socket. The test drives its delegate with
/// deterministic data, including a framework callback larger than the application queue.
final class SilentResponse: Sendable {
  let response: StreamingResponse
  private let session: URLSession
  private let task: URLSessionDataTask

  init(errorForStatus: @escaping @Sendable (Int) -> ProviderError = ProviderError.init(httpStatus:)) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SilentProtocol.self]
    let request = URLRequest(url: URL(string: "https://speech.invalid")!)
    response = StreamingResponse(request, errorForStatus: errorForStatus, configuration: configuration)
    session = URLSession(configuration: configuration)
    task = session.dataTask(with: request)
  }

  deinit { response.cancel(); session.invalidateAndCancel() }

  /// Blocks while the response queue is full, as the delegate callback does.
  func receive(_ data: Data) { response.urlSession(session, dataTask: task, didReceive: data) }
  func receive(status: Int) {
    let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: status,
      httpVersion: nil, headerFields: nil)!
    self.response.urlSession(session, dataTask: task, didReceive: response) { _ in }
  }
  func complete(_ error: (any Error)? = nil) {
    response.urlSession(session, task: task, didCompleteWithError: error)
  }
}

private final class SilentProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {}
  override func stopLoading() {}
}
