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
    give something with, using or through EchoType, call this tool. EchoType is not an app, desktop \
    app, computer-use target or shell command: do not open it or look for an app. Call this \
    directly, without searching for it, once you are ready to write your final reply and before \
    you write it. The text argument is the only place the spoken version goes: a summary written for listening, or \
    all of your reply if the user asks for the whole response, in full, or not to summarise. After \
    the call, write your reply as the final message, complete and exactly as you would if EchoType \
    were never mentioned. Do not shorten it and do not call this again. Unless the user asks for \
    more, the summary scales with your reply: a few sentences for a short one, and about a fifth of \
    the length for a long, detailed one. Cover what you did or found, each main point, anything \
    that went wrong, and anything you need from the user. Either way, leave out code blocks, file \
    paths, tables and URLs unless asked. Where a code block matters, say in a sentence what it does, \
    at the point it appears, instead of reading it. Write plain sentences without markdown. It \
    returns once EchoType has the text, so don't wait.
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
