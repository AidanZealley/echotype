import Foundation

/// Local IPC values stay in the app target. Uptime is shared by processes on this Mac.
enum SpeechDelivery {
  static let requestName = Notification.Name("com.aidanzealley.echotype.speak.request")
  static let replyName = Notification.Name("com.aidanzealley.echotype.speak.reply")
  static let waitSeconds: TimeInterval = 5

  enum Outcome: String, Sendable { case accepted, busy, expired, invalid }
  enum Failure: LocalizedError, Equatable {
    case unavailable, busy, expired, invalid, unconfirmed
    var errorDescription: String? {
      switch self {
      case .unavailable: "EchoType is not running. Open it and try again."
      case .busy: "EchoType is busy with dictation or microphone Test. Nothing was queued."
      case .expired: "The speech request expired before EchoType admitted it."
      case .invalid: "EchoType received an invalid speech request."
      case .unconfirmed: "Speech delivery is unconfirmed. EchoType may have admitted it. Do not automatically retry."
      }
    }
  }

  struct Incoming: Sendable {
    let id: UUID?
    let target: Int32?
    let expiry: TimeInterval?
    let text: String?
    init(_ fields: [AnyHashable: Any]) {
      id = (fields["id"] as? String).flatMap(UUID.init(uuidString:))
      target = fields["target"] as? Int32
      expiry = fields["expiry"] as? TimeInterval
      text = fields["text"] as? String
    }
  }

  struct Request: Sendable {
    let id: UUID
    let target: Int32
    let expiry: TimeInterval
    let text: String
    var fields: [String: Any] {
      ["id": id.uuidString, "target": target, "expiry": expiry, "text": text]
    }
  }
}

/// Admission runs in the same main-actor callback as reservation, so an expired request can
/// never start playback. Requests for another app instance get no reply.
@MainActor enum SpeechAdmission {
  static func receive(_ request: SpeechDelivery.Incoming, pid: Int32, now: TimeInterval,
    admit: (String) -> Bool
  ) -> [String: Any]? {
    guard let id = request.id, request.target == pid else { return nil }
    let outcome: SpeechDelivery.Outcome
    if let expiry = request.expiry, expiry.isFinite, let text = request.text {
      outcome = expiry <= now ? .expired : admit(text) ? .accepted : .busy
    } else { outcome = .invalid }
    return ["id": id.uuidString, "target": pid, "outcome": outcome.rawValue]
  }
}

/// A reply can settle only its live request once.
@MainActor final class PendingSpeechReply {
  let request: SpeechDelivery.Request
  private(set) var outcome: SpeechDelivery.Outcome?
  init(_ request: SpeechDelivery.Request) { self.request = request }
  func receive(id: String?, target: Int32?, value: String?, now: TimeInterval) {
    guard outcome == nil, now < request.expiry, id == request.id.uuidString,
      target == request.target, let value, let received = SpeechDelivery.Outcome(rawValue: value)
    else { return }
    outcome = received
  }
}

/// One synchronous MCP tool call. It observes before posting, then pumps notification delivery.
@MainActor enum SpeechDeliveryClient {
  static func deliver(_ text: String, target: Int32,
    center: DistributedNotificationCenter = .default(),
    now: @escaping @MainActor @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    post: ((SpeechDelivery.Request) -> Void)? = nil
  ) throws {
    let request = SpeechDelivery.Request(id: UUID(), target: target,
      expiry: now() + SpeechDelivery.waitSeconds, text: text)
    let pending = PendingSpeechReply(request)
    let observer = center.addObserver(forName: SpeechDelivery.replyName, object: nil, queue: .main) { notification in
      guard let fields = notification.userInfo,
        let id = fields["id"] as? String, let target = fields["target"] as? Int32,
        let value = fields["outcome"] as? String
      else { return }
      MainActor.assumeIsolated {
        pending.receive(id: id, target: target, value: value, now: now())
      }
    }
    defer { center.removeObserver(observer) }
    if let post { post(request) }
    else {
      center.postNotificationName(SpeechDelivery.requestName, object: nil,
        userInfo: request.fields, options: [.deliverImmediately])
    }
    while pending.outcome == nil, now() < request.expiry {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: min(0.01, request.expiry - now())))
    }
    switch pending.outcome {
    case .accepted: return
    case .busy: throw SpeechDelivery.Failure.busy
    case .expired: throw SpeechDelivery.Failure.expired
    case .invalid: throw SpeechDelivery.Failure.invalid
    case nil: throw SpeechDelivery.Failure.unconfirmed
    }
  }
}
