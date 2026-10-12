import AppKit
import EchoTypeCore

/// The stdio process creates no NSApplication, settings, hotkeys, capture or audio services.
@MainActor enum MCPProcess {
  /// Answers each line of stdin until it ends. Replies are only awaited inside `deliver`,
  /// which services the main run loop itself, so blocking on stdin starves nothing.
  static func run() {
    let server = MCPServer(deliver: deliver)
    while let line = readLine() {
      // `MCPServer` answers a blank line with a parse error, which clients don't expect.
      guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
      if let response = server.handle(line) {
        print(response)
        fflush(stdout)
      }
    }
  }

  private static func deliver(_ text: String) throws {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.aidanzealley.echotype")
      .first(where: { $0.processIdentifier != getpid() && !$0.isTerminated })
    else { throw SpeechDelivery.Failure.unavailable }
    try SpeechDeliveryClient.deliver(text, target: app.processIdentifier)
  }
}
