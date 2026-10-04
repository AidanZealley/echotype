import EchoTypeCore
import Foundation

/// The local services the bench measures, each by its own command.
enum LocalService: String {
  case transcription
  case cleanup
}

/// What `transcribe` and `cleanup` share: the options they take, and getting a provider's
/// credential and readiness. Parsed by hand like the rest of the bench.
struct RunOptions {
  let arguments: [String]
  var providerID: String?
  /// `--candidate <service>=<name>`: the local candidate to measure, where the build's is not.
  var candidates: [LocalService: String] = [:]
  var fast = false
  var withCleanup = false
  /// How many times the selected samples run in one process. Repeats make warm distributions.
  var repeats = 1
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
      case "--candidate":
        let parts = rest.popFirst()?.split(separator: "=", maxSplits: 1).map(String.init) ?? []
        guard parts.count == 2, let service = LocalService(rawValue: parts[0]) else {
          throw BenchError("--candidate needs transcription=<name> or cleanup=<name>")
        }
        candidates[service] = parts[1]
      case "--fast": fast = true
      case "--cleanup": withCleanup = true
      case "--repeat":
        guard let value = rest.popFirst(), let count = Int(value), count >= 1 else {
          throw BenchError("--repeat needs a whole number of at least 1")
        }
        repeats = count
      case "--synthetic": synthetic = true
      case _ where argument.hasPrefix("--"): throw BenchError("unknown option \(argument)")
      default: ids.append(argument)
      }
    }
  }

  /// The provider for `--provider`. The local provider is not in `Providers.all`, so it is
  /// built here. Its candidates are those of `service`, the one this command measures, so only
  /// that service's models are prepared and its memory and preparation figures are its own.
  func provider(measuring service: LocalService) throws -> Provider {
    if providerID == Provider.local.id.rawValue { return try .local(localSelection(measuring: service)) }
    let known = (Providers.all + [.local]).map(\.id.rawValue)
    guard let providerID, let provider = Providers.all.first(where: { $0.id.rawValue == providerID })
    else { throw BenchError("--provider must be one of: \(known.joined(separator: ", "))") }
    return provider
  }

  /// What `run.json` records: the local provider's candidate, and nothing for the others.
  func recordedSelection(measuring service: LocalService) throws -> LocalSelection? {
    providerID == Provider.local.id.rawValue ? try localSelection(measuring: service) : nil
  }

  /// The `--candidate` for `service`, or the build's. A candidate for another service is an
  /// error rather than ignored, since the run would not use it.
  private func localSelection(measuring service: LocalService) throws -> LocalSelection {
    if let other = candidates.keys.first(where: { $0 != service && !(service == .transcription && withCleanup) }) {
      throw BenchError("--candidate \(other.rawValue)=<name> does not apply to this command.")
    }
    switch service {
    case .transcription:
      return LocalSelection(
        transcription: candidates[service] ?? LocalSelection.build.transcription,
        cleanup: withCleanup ? candidates[.cleanup] ?? LocalSelection.build.cleanup : nil)
    case .cleanup:
      return LocalSelection(cleanup: candidates[service] ?? LocalSelection.build.cleanup)
    }
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

/// Waits while the provider is setting up a service, such as downloading a speech model, and
/// records how long that took and what it said. `state` picks the service from the provider's
/// readiness; nil means the provider has no such service.
func requireReady(
  _ provider: Provider, _ service: String, state select: (ServiceReadiness) -> ServiceState?
) async throws -> Preparation {
  let request = ReadinessRequest(language: Language.english.tag, voice: provider.voice.voices[0].id)
  let check = { await provider.readiness.check(request) }
  let startedAt = Date()
  let clock = ContinuousClock.now
  var messages: [Preparation.Message] = []
  // Subscribed before the first check, so a change in between is not missed.
  let changes = provider.readiness.changes()
  var state = await select(check())
  var updates = changes.makeAsyncIterator()
  while state?.status == .waiting {
    let message = state?.message ?? "\(service) is setting up"
    print("Waiting: \(message)")
    if messages.last?.message != message {
      messages.append(.init(ms: (ContinuousClock.now - clock) / .milliseconds(1), message: message))
    }
    guard await updates.next() != nil else { break }
    state = await select(check())
  }
  guard state?.status == .ready else {
    throw BenchError("\(provider.name) \(service) is not ready: \(state?.message ?? "unavailable")")
  }
  return Preparation(startedAt: startedAt, readyAt: Date(), messages: messages)
}
