import AppKit
import EchoTypeCore

/// The `--mcp` process: an MCP stdio server that hands `speak` text to the running app. It
/// never creates an `NSApplication`, a hotkey monitor or a login item claim.
enum MCPProcess {
  private struct NotRunning: LocalizedError {
    var errorDescription: String? { "EchoType is not running. Open it and try again." }
  }

  /// Answers each line of stdin until it ends.
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
    guard
      NSRunningApplication.runningApplications(withBundleIdentifier: "com.aidanzealley.echotype")
        .contains(where: { $0.processIdentifier != getpid() })
    else { throw NotRunning() }
    // `deliverImmediately` gets past the suspension an inactive menu bar app is under.
    DistributedNotificationCenter.default().postNotificationName(
      SpeakNotification.name, object: nil,
      userInfo: [SpeakNotification.textKey: text], options: [.deliverImmediately])
  }
}
