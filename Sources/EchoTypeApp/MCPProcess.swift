import AppKit
import EchoTypeCore

/// Reads stdin off the main thread so a quiet client cannot starve distributed replies.
private final class MCPInput: @unchecked Sendable {
  private let lock = NSLock()
  private let consumed = DispatchSemaphore(value: 0)
  private var line: String?
  private var ended = false

  func read() {
    while let line = readLine() {
      lock.withLock { self.line = line }
      consumed.wait()
    }
    lock.withLock { ended = true }
  }

  func next() -> (line: String?, ended: Bool) {
    let result = lock.withLock {
      let result = (line, ended)
      line = nil
      return result
    }
    if result.0 != nil { consumed.signal() }
    return result
  }
}

/// The stdio process creates no NSApplication, settings, hotkeys, capture or audio services.
@MainActor enum MCPProcess {
  static func run() {
    let input = MCPInput()
    DispatchQueue.global().async { input.read() }
    let server = MCPServer(deliver: deliver)
    while true {
      let next = input.next()
      if let line = next.line {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
        if let response = server.handle(line) {
          print(response)
          fflush(stdout)
        }
      } else if next.ended { return }
      else { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01)) }
    }
  }

  private static func deliver(_ text: String) throws {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.aidanzealley.echotype")
      .first(where: { $0.processIdentifier != getpid() && !$0.isTerminated })
    else { throw SpeechDelivery.Failure.unavailable }
    try SpeechDeliveryClient.deliver(text, target: app.processIdentifier)
  }
}
