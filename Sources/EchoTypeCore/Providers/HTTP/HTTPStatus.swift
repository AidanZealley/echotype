extension ProviderError {
  /// The default mapping of a failed HTTP status. A provider with its own conventions builds on
  /// this rather than replacing it.
  public init(httpStatus: Int) {
    switch httpStatus {
    case 401, 403: self = .rejectedCredential
    case 429: self = .rateLimited
    case 500..<600: self = .unavailable
    default: self = .failed("HTTP \(httpStatus)")
    }
  }
}
