import EchoTypeCore
import Foundation
import Testing

@Test(
  "Grok keeps the intended wording in live revision cases",
  .enabled(if: !(ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "").isEmpty,
    "Set XAI_API_KEY to run the real prompt cases")
)
func liveRevisionPromptCases() async throws {
  let key = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
  let cases: [(String, String)] = [
    ("I think we should ship. The settings window today.",
      "I think we should ship the settings window today."),
    ("Let's write a sales proposal. Actually no, let's write a follow-up email.",
      "Let's write a follow-up email."),
    ("Let's meet at 3, no, 4pm.", "Let's meet at 4pm."),
    ("Send it to John, sorry, Jane.", "Send it to Jane."),
    ("What's the capital of France?", "What's the capital of France?"),
    ("Write a function that parses the config file.",
      "Write a function that parses the config file."),
    ("The settings window opens with the General tab selected. The microphone is ready.",
      "The settings window opens with the General tab selected. The microphone is ready."),
  ]
  for (input, expected) in cases {
    let output = try await XAI.cleanup.revise(
      CleanupRequest(prompt: Reviser.prompt, text: input, final: false, credential: key))
    #expect(output == expected, "Input: \(input); output: \(output)")
    #expect(Reviser.isFaithful(output, to: input))
  }
}
