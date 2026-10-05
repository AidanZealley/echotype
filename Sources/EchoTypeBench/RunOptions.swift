import EchoTypeCore
import Foundation

/// The services the bench measures, each by its own command.
enum LocalService: String, CaseIterable {
  case transcription
  case cleanup
  case voice

  /// How a provider's readiness reports this service.
  var state: (ServiceReadiness) -> ServiceState? {
    switch self {
    case .transcription: { $0.transcription }
    case .cleanup: { $0.cleanup }
    case .voice: { $0.voice }
    }
  }
}

/// What `transcribe`, `cleanup` and `speak` share: the options they take, and getting a provider's
/// credential and readiness. Parsed by hand like the rest of the bench.
struct RunOptions {
  let arguments: [String]
  var providerID: String?
  /// `--candidate <service>=<name>`: a local candidate to prepare, where the build's is not. A
  /// local run prepares every service named here as well as the one it measures.
  var candidates: [LocalService: String] = [:]
  var fast = false
  var withCleanup = false
  /// Only `speak` takes `--voice` and `--speed`.
  var voice: String?
  var speed: Double?
  /// How many times the selected samples run in one process. Repeats make warm distributions.
  var repeats = 1
  /// Only `transcribe` takes it; `cleanup` and `speak` reject it.
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
          let accepted = LocalService.allCases.map { "\($0.rawValue)=<name>" }.joined(separator: " or ")
          throw BenchError("--candidate takes \(accepted)")
        }
        candidates[service] = parts[1]
      case "--fast": fast = true
      case "--cleanup": withCleanup = true
      case "--voice":
        guard let value = rest.popFirst() else { throw BenchError("--voice needs a value") }
        voice = value
      case "--speed":
        guard let value = rest.popFirst(), let multiplier = Double(value) else {
          throw BenchError("--speed needs a number")
        }
        speed = multiplier
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

  /// The services a run prepares: the one it measures, cleanup for `transcribe --cleanup`, and
  /// for Local every service named with `--candidate`, so a combination's memory can be
  /// measured.
  func services(measuring measured: LocalService) -> [LocalService] {
    let named = providerID == Provider.local.id.rawValue ? Set(candidates.keys) : []
    let wanted = named.union([measured]).union(withCleanup ? [LocalService.cleanup] : [])
    return LocalService.allCases.filter(wanted.contains)
  }

  /// The provider for `--provider`. For Local, build only the services this run prepares, so
  /// the footprint is theirs alone.
  func provider(measuring measured: LocalService) throws -> Provider {
    let known = Providers.all.map(\.id.rawValue)
    guard let providerID, let provider = Providers.all.first(where: { $0.id.rawValue == providerID })
    else { throw BenchError("--provider must be one of: \(known.joined(separator: ", "))") }
    return provider.id == Provider.local.id ? try .local(localSelection(measuring: measured)) : provider
  }

  /// What `run.json` records: the local provider's candidates, and nothing for the others.
  func recordedSelection(measuring measured: LocalService) -> LocalSelection? {
    providerID == Provider.local.id.rawValue ? localSelection(measuring: measured) : nil
  }

  /// The `--candidate` for each prepared service, or the build's.
  private func localSelection(measuring measured: LocalService) -> LocalSelection {
    let services = services(measuring: measured)
    return LocalSelection(
      transcription: services.contains(.transcription)
        ? candidates[.transcription] ?? LocalSelection.build.transcription : nil,
      cleanup: services.contains(.cleanup) ? candidates[.cleanup] ?? LocalSelection.build.cleanup : nil,
      voice: services.contains(.voice) ? candidates[.voice] ?? LocalSelection.build.voice : nil)
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

/// Waits while the provider is setting up the services, such as downloading a speech model, and
/// records how long that took and what it said. A service the provider does not have is not ready.
func requireReady(
  _ provider: Provider, voice: String? = nil, services: [LocalService]
) async throws -> Preparation {
  let request = ReadinessRequest(language: Language.english.tag, voice: voice ?? provider.voice.voices[0].id)
  let names = services.map(\.rawValue)
  let label = names.joined(separator: " and ")
  let check = { () async -> ServiceState? in
    let readiness = await provider.readiness.check(request)
    let states = services.map { $0.state(readiness) }
    if states.contains(where: { $0 == nil }) { return nil }
    let all = states.compactMap { $0 }
    if let unavailable = all.first(where: { $0.status == .unavailable }) { return unavailable }
    let waiting = all.filter { $0.status == .waiting }.compactMap(\.message)
    return waiting.isEmpty ? .ready : .waiting(waiting.joined(separator: "; "))
  }
  let startedAt = Date()
  let clock = ContinuousClock.now
  var messages: [Preparation.Message] = []
  // Subscribed before the first check, so a change in between is not missed.
  let changes = provider.readiness.changes()
  var state = await check()
  var updates = changes.makeAsyncIterator()
  while state?.status == .waiting {
    let message = state?.message ?? "\(label) is setting up"
    print("Waiting: \(message)")
    if messages.last?.message != message {
      messages.append(.init(ms: (ContinuousClock.now - clock) / .milliseconds(1), message: message))
    }
    guard await updates.next() != nil else { break }
    state = await check()
  }
  guard state?.status == .ready else {
    throw BenchError("\(provider.name) \(label) is not ready: \(state?.message ?? "unavailable")")
  }
  return Preparation(startedAt: startedAt, readyAt: Date(), messages: messages, services: names)
}
