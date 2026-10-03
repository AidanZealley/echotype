import EchoTypeCore

/// Dictation, Test or reading did not start because a service it uses is not ready.
struct NotReady: Error {
  /// `.waiting` or `.unavailable`, with the provider's reason.
  let state: ServiceState
}

/// The provider needs a credential that is not stored, so nothing was started.
struct MissingCredential: Error {}

extension ServiceState {
  /// The provider's reason, or nil when ready.
  var reason: String? {
    switch self {
    case .ready: nil
    case .waiting(let reason), .unavailable(let reason): reason
    }
  }

  func requireReady() throws {
    if self != .ready { throw NotReady(state: self) }
  }
}
