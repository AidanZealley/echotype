import Foundation

extension XAI {
  /// One chat request per revision. A final revision has a shorter timeout because the user
  /// is waiting for insertion.
  enum Cleanup {
    private static let session: URLSession = {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.timeoutIntervalForResource = 5
      return URLSession(configuration: configuration)
    }()

    static func revise(_ cleanup: CleanupRequest) async throws -> String {
      var request = URLRequest(url: URL(string: "https://api.x.ai/v1/chat/completions")!)
      request.httpMethod = "POST"
      request.timeoutInterval = cleanup.final ? 3 : 5
      if let credential = cleanup.credential {
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
      }
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(Body(messages: [
        .init(role: "system", content: cleanup.prompt), .init(role: "user", content: cleanup.text)
      ]))
      let (data, response) = try await session.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard (200..<300).contains(status) else { throw XAI.error(httpStatus: status) }
      let choices = try JSONDecoder().decode(Response.self, from: data).choices
      guard let first = choices.first else {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No revision choice"))
      }
      return first.message.content
    }

    private struct Body: Encodable {
      let model = "grok-4.3"
      let reasoningEffort = "none"
      let temperature = 0
      let messages: [Message]

      enum CodingKeys: String, CodingKey {
        case model, temperature, messages
        case reasoningEffort = "reasoning_effort"
      }
    }

    private struct Message: Codable {
      let role: String
      let content: String
    }

    private struct Response: Decodable {
      let choices: [Choice]
      struct Choice: Decodable { let message: Message }
    }
  }
}
