import EchoTypeCore
import Testing

@Test(
  "The last sentence asking for a spoken reply with the name matches",
  arguments: [
    "reply with EchoType",
    "Fix the bug. Respond with echo type.",
    "read the response with EchoType, minus any code blocks",
    "tell me what failed with EchoType",
    "Say it via Echotype!",
  ])
func matchesReplyRequests(_ text: String) {
  #expect(ReplyRequest.matches(text))
}

@Test(
  "Text without both the name as an object and a verb in the last sentence does not match",
  arguments: [
    "with EchoType",
    "reply with EchoType. Then fix the tests.",
    "reply to me with the summary",
    "make EchoType read faster",
    "the reply bug in EchoType",
  ])
func rejectsOtherText(_ text: String) {
  #expect(!ReplyRequest.matches(text))
}
