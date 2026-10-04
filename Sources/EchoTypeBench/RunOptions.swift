import EchoTypeCore
import Foundation

/// What `transcribe` and `cleanup` share: the options they take, and getting a provider's
/// credential and readiness. Parsed by hand like the rest of the bench.
struct RunOptions {
  let arguments: [String]
  var providerID: String?
  var fast = false
  /// Only `transcribe` takes it; `cleanup` rejects it.
  var synthetic = false
  var ids: [String] = []

  init(parsing arguments: [String]) throws {
    self.arguments = arguments
    var rest = arguments[...]
    while let argument = rest.popFirst() {
      switch argument {
      case "--provider":
        guard let value = rest.popFirst() else { throw BenchError("--provider needs a value") }
        providerID = value
      case "--fast": fast = true
      case "--synthetic": synthetic = true
      case _ where argument.hasPrefix("--"): throw BenchError("unknown option \(argument)")
      default: ids.append(argument)
      }
    }
  }

  func provider() throws -> Provider {
    let known = Providers.all.map(\.id.rawValue)
    guard let providerID, let provider = Providers.all.first(where: { $0.id.rawValue == providerID })
    else { throw BenchError("--provider must be one of: \(known.joined(separator: ", "))") }
    return provider
  }
}

/// A key provider's credential comes from the environment, as in `LiveProtocolTests`, rather than
/// the app's Keychain item.
func credential(for provider: Provider) throws -> String? {
  guard case .apiKey = provider.credential else { return nil }
  let name = "\(provider.id.rawValue.uppercased())_API_KEY"
  guard let key = ProcessInfo.processInfo.environment[name], !key.isEmpty else {
    throw BenchError("\(name) is not set; \(provider.name) needs it.")
  }
  return key
}

/// Waits while the provider is setting up a service, such as downloading a speech model. `state`
/// picks the service from the provider's readiness; nil means the provider has no such service.
func requireReady(
  _ provider: Provider, _ service: String, state select: (ServiceReadiness) -> ServiceState?
) async throws {
  let request = ReadinessRequest(language: Language.english.tag, voice: provider.voice.voices[0].id)
  let check = { await provider.readiness.check(request) }
  // Subscribed before the first check, so a change in between is not missed.
  let changes = provider.readiness.changes()
  var state = await select(check())
  var updates = changes.makeAsyncIterator()
  while state?.status == .waiting {
    print("Waiting: \(state?.message ?? "\(service) is setting up")")
    guard await updates.next() != nil else { break }
    state = await select(check())
  }
  guard state?.status == .ready else {
    throw BenchError("\(provider.name) \(service) is not ready: \(state?.message ?? "unavailable")")
  }
}
