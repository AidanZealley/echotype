import Foundation

/// The MCP server behind `EchoTypeApp --mcp`: one `speak` tool over newline-delimited
/// JSON-RPC. It is dual-era. Modern clients (2026-07-28) send a protocol version in
/// `params._meta` on every request and never handshake; legacy clients (2025-11-25) open
/// with `initialize`, which selects legacy semantics for the rest of the process. This is a
/// compatibility boundary, so it stays until the legacy clients are gone. Hand-written
/// because the official Swift SDK implements only 2025-11-25 and one tool doesn't justify it.
///
/// It knows nothing about stdin or the app: `deliver` hands the text over and throws when
/// it can't, and the caller owns the transport.
public final class MCPServer {
  public static let modernVersion = "2026-07-28"
  public static let legacyVersion = "2025-11-25"
  public static let supportedVersions = [modernVersion, legacyVersion]

  /// The `speak` description and the server `instructions`. Not every client reads
  /// instructions, so the description has to work on its own.
  public static let speakGuidance = """
    Speaks text aloud through EchoType. When the user asks you to reply, respond, read, say or \
    give something with, using or through EchoType, prepare the full written answer at its normal \
    level of detail. Then call this MCP tool once before sending that full written answer. Do not \
    shorten the written answer for speech. EchoType here is the MCP server, not a desktop app or \
    shell command; do not look for or open an app. If the user asks \
    to hear the whole response, in full or without summarising, give the tool the entire answer \
    instead of a summary. Otherwise, give the tool a separate spoken summary: a few sentences for \
    a short reply or about a fifth of a long reply. Cover the main points, what went wrong and \
    anything needed from the user. For summaries, describe relevant code blocks in plain sentences \
    and omit markdown, file paths, tables and URLs unless asked. Put spoken text only in the tool's \
    text argument. After the call, send the full written answer as the final message. The tool returns once \
    EchoType admits the reading, so do not wait for playback.
    """

  private typealias JSON = [String: Any]

  private static let versionKey = "io.modelcontextprotocol/protocolVersion"
  private static let serverInfoKey = "io.modelcontextprotocol/serverInfo"
  // Caching hints on discover and tools/list results. The spec allows only "public" or "private".
  private static var cacheHints: JSON { ["ttlMs": 3_600_000, "cacheScope": "public"] }
  private static var serverInfo: JSON { ["name": "echotype", "version": "1.0.0"] }
  private static var tools: [JSON] { [
    [
      "name": "speak",
      "description": speakGuidance,
      "inputSchema": [
        "type": "object",
        "properties": ["text": ["type": "string", "description": "What to say aloud."]],
        "required": ["text"],
      ] as JSON,
    ]
  ] }

  private let deliver: (String) throws -> Void
  private var isLegacy = false

  public init(deliver: @escaping (String) throws -> Void) {
    self.deliver = deliver
  }

  /// Handles one message and returns the response line, or nil for a notification.
  public func handle(_ line: String) -> String? {
    guard let data = line.data(using: .utf8),
      let request = (try? JSONSerialization.jsonObject(with: data)) as? JSON
    else {
      return encode(id: NSNull(), error: (-32700, "Parse error", nil))
    }
    // A message without an id is a notification and never gets a response.
    guard let id = request["id"] else { return nil }

    let method = request["method"] as? String ?? ""
    let params = request["params"] as? JSON ?? [:]

    if method == "initialize" { isLegacy = true }
    if !isLegacy, let error = unsupportedVersionError(params) {
      return encode(id: id, error: error)
    }

    switch method {
    case "initialize":
      return encode(
        id: id,
        result: [
          "protocolVersion": Self.legacyVersion,
          "capabilities": ["tools": JSON()],
          "serverInfo": Self.serverInfo,
          "instructions": Self.speakGuidance,
        ])
    case "server/discover":
      return encode(
        id: id,
        result: [
          "supportedVersions": Self.supportedVersions,
          "capabilities": ["tools": JSON()],
          "instructions": Self.speakGuidance,
          "_meta": [Self.serverInfoKey: Self.serverInfo],
        ].merging(Self.cacheHints) { $1 })
    case "ping":
      return encode(id: id, result: [:])
    case "tools/list":
      return encode(id: id, result: ["tools": Self.tools].merging(Self.cacheHints) { $1 })
    case "tools/call":
      return encode(id: id, result: call(params))
    default:
      return encode(id: id, error: (-32601, "Method not found: \(method)", nil))
    }
  }

  private func unsupportedVersionError(_ params: JSON) -> (Int, String, JSON?)? {
    guard let meta = params["_meta"] as? JSON, let version = meta[Self.versionKey] as? String,
      !Self.supportedVersions.contains(version)
    else { return nil }
    return (
      -32022, "Unsupported protocol version: \(version)",
      ["supported": Self.supportedVersions, "requested": version]
    )
  }

  private func call(_ params: JSON) -> JSON {
    guard params["name"] as? String == "speak",
      let text = (params["arguments"] as? JSON)?["text"] as? String
    else { return toolResult("speak needs a string `text`.", isError: true) }
    do {
      try deliver(text)
      return toolResult("Speaking.")
    } catch {
      return toolResult(error.localizedDescription, isError: true)
    }
  }

  private func toolResult(_ text: String, isError: Bool = false) -> JSON {
    ["content": [["type": "text", "text": text]], "isError": isError]
  }

  private func encode(id: Any, result: JSON) -> String? {
    serialise(["jsonrpc": "2.0", "id": id, "result": result.merging(["resultType": "complete"]) { $1 }])
  }

  private func encode(id: Any, error: (code: Int, message: String, data: JSON?)) -> String? {
    var body: JSON = ["code": error.code, "message": error.message]
    body["data"] = error.data
    return serialise(["jsonrpc": "2.0", "id": id, "error": body])
  }

  private func serialise(_ message: JSON) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
}
