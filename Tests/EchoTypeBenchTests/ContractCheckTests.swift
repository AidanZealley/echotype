import EchoTypeCore
import Testing

@testable import EchoTypeBench

@Test("Committed text that is rewritten rather than extended is a violation")
func committedTextMustOnlyGrow() {
  var check = ContractCheck()
  check.observe(.ready)
  check.observe(.transcript(Transcript(committed: "Hello")))
  check.observe(.transcript(Transcript(committed: "Hello world")))
  #expect(check.violations.isEmpty)

  check.observe(.transcript(Transcript(committed: "Hullo world")))
  #expect(check.violations == ["committed text did not only grow: \"Hello world\" became \"Hullo world\""])
}

@Test("A session must start with ready and end with finished after finish")
func readyFirstAndFinishedLast() {
  var check = ContractCheck()
  check.observe(.speech)
  check.observe(.ready)
  check.finishWasCalled()
  #expect(check.violations.count == 3)
}
