import EchoTypeCore

/// Dictation, Test or reading did not start because a service it uses is not ready.
struct NotReady: Error {
  /// Waiting or unavailable, with the provider's message.
  let state: ServiceState
}

/// The provider needs a credential that is not stored, so nothing was started.
struct MissingCredential: Error {}

extension ServiceState {
  func requireReady() throws {
    if status != .ready { throw NotReady(state: self) }
  }
}
