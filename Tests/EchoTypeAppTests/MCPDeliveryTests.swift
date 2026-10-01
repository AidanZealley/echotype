import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1))) @MainActor struct MCPDeliveryTests {
  @Test func repliesSettleOnlyTheLiveMatchingRequestOnce() {
    let request = SpeechDelivery.Request(id: UUID(), target: 42, expiry: 15, text: "Hello")
    let pending = PendingSpeechReply(request)
    pending.receive(id: UUID().uuidString, target: 42, value: "accepted", now: 10)
    pending.receive(id: request.id.uuidString, target: 43, value: "accepted", now: 10)
    pending.receive(id: request.id.uuidString, target: 42, value: "unknown", now: 10)
    pending.receive(id: request.id.uuidString, target: 42, value: "accepted", now: 15)
    #expect(pending.outcome == nil)
    pending.receive(id: request.id.uuidString, target: 42, value: "busy", now: 14)
    pending.receive(id: request.id.uuidString, target: 42, value: "accepted", now: 14)
    #expect(pending.outcome == .busy)
  }

  @Test func expiryAndMalformedRequestsCannotAdmit() {
    let request = SpeechDelivery.Request(id: UUID(), target: 42, expiry: 15, text: "Hello")
    var calls = 0
    func receive(_ fields: [String: Any], now: Double = 15) -> String? {
      SpeechAdmission.receive(.init(fields), pid: 42, now: now) { _ in calls += 1; return true }?["outcome"] as? String
    }
    #expect(receive(request.fields) == "expired")
    var invalid = request.fields; invalid["text"] = 99
    #expect(receive(invalid, now: 10) == "invalid")
    invalid = request.fields; invalid["expiry"] = Double.nan
    #expect(receive(invalid, now: 10) == "invalid")
    invalid = request.fields; invalid["target"] = 43
    #expect(receive(invalid, now: 10) == nil)
    invalid = request.fields; invalid["id"] = "bad"
    #expect(receive(invalid, now: 10) == nil)
    #expect(calls == 0)
  }

  @Test func lostReplyIsUnconfirmedAndNeverReposts() throws {
    var time = 10.0
    var posts = 0
    #expect(throws: SpeechDelivery.Failure.unconfirmed) {
      try SpeechDeliveryClient.deliver("Hello", target: 42, now: {
        defer { time += 5 }
        return time
      }, post: { _ in posts += 1 })
    }
    #expect(posts == 1)
  }
  @Test(arguments: [false, true])
  func deliveryErrorsKeepTheirMeaningInBothProtocolModes(_ legacy: Bool) throws {
    let failures: [SpeechDelivery.Failure] = [.unavailable, .busy, .expired, .invalid, .unconfirmed]
    var messages: Set<String> = []
    for failure in failures {
      let server = MCPServer { _ in throw failure }
      if legacy { _ = server.handle(#"{"id":1,"method":"initialize"}"#) }
      let line = try #require(server.handle(#"{"id":2,"method":"tools/call","params":{"name":"speak","arguments":{"text":"Hello"}}}"#))
      let response = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
      let result = try #require(response["result"] as? [String: Any])
      #expect(result["isError"] as? Bool == true)
      let content = try #require(result["content"] as? [[String: String]])
      #expect(content.first?["text"] == failure.localizedDescription)
      messages.insert(failure.localizedDescription)
    }
    #expect(messages.count == failures.count)
  }

}
