import EchoTypeCore
import Foundation
import Testing

private final class Delivered: @unchecked Sendable {
  var texts: [String] = []
}

private func parse(_ line: String?) throws -> [String: Any] {
  let line = try #require(line)
  return try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
}

@Test("A legacy client initialises, then calls speak")
func legacyExchangeDeliversText() throws {
  let delivered = Delivered()
  let server = MCPServer { delivered.texts.append($0) }

  let initialised = try parse(
    server.handle(
      #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}"#))
  let result = try #require(initialised["result"] as? [String: Any])
  #expect(result["protocolVersion"] as? String == "2025-11-25")
  #expect(result["instructions"] as? String == MCPServer.speakGuidance)
  #expect(server.handle(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)

  let called = try parse(
    server.handle(
      #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"speak","arguments":{"text":"Hello"}}}"#
    ))
  #expect((called["result"] as? [String: Any])?["isError"] as? Bool == false)
  #expect(delivered.texts == ["Hello"])
}

@Test("A modern client calls speak with its version in _meta and no handshake")
func modernRequestDeliversText() throws {
  let delivered = Delivered()
  let server = MCPServer { delivered.texts.append($0) }

  let discovered = try parse(
    server.handle(
      #"{"jsonrpc":"2.0","id":1,"method":"server/discover","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}"#
    ))
  let discovery = try #require(discovered["result"] as? [String: Any])
  #expect(discovery["instructions"] as? String == MCPServer.speakGuidance)

  _ = server.handle(
    #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"},"name":"speak","arguments":{"text":"Hi"}}}"#
  )
  #expect(delivered.texts == ["Hi"])

  let listed = try parse(
    server.handle(
      #"{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}"#
    ))
  #expect((listed["result"] as? [String: Any])?["cacheScope"] as? String == "public")
}

@Test("A modern request naming an unsupported version gets -32022 with the supported list")
func unsupportedVersionIsRejected() throws {
  let server = MCPServer { _ in }
  let response = try parse(
    server.handle(
      #"{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2030-01-01"}}}"#
    ))
  let error = try #require(response["error"] as? [String: Any])
  #expect(error["code"] as? Int == -32022)
  let data = try #require(error["data"] as? [String: Any])
  #expect(data["supported"] as? [String] == ["2026-07-28", "2025-11-25"])
}

@Test("A failed delivery becomes a tool error carrying its message")
func failedDeliveryIsAToolError() throws {
  struct AppNotRunning: LocalizedError { var errorDescription: String? { "EchoType isn't running." } }
  let server = MCPServer { _ in throw AppNotRunning() }
  let response = try parse(
    server.handle(
      #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"speak","arguments":{"text":"Hi"}}}"#
    ))
  let result = try #require(response["result"] as? [String: Any])
  #expect(result["isError"] as? Bool == true)
  let content = try #require(result["content"] as? [[String: Any]])
  #expect(content.first?["text"] as? String == "EchoType isn't running.")
}
