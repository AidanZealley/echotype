import FluidAudio
import Testing

@testable import EchoTypeCore

@Suite struct KokoroTextTests {
  @Test("Dotted clock meridiems reach the frontend as separate letter names")
  func meridiems() {
    let text = "At 11:45 a.m. and 01:05 P.M. we read the report."
    let prepared = KokoroText.prepare(text)
    #expect(prepared == "At 11:45 A M. and 01:05 P M. we read the report.")
    let normalized = NemoTextNormalizer.normalize(prepared, language: .english)
    #expect(normalized.contains("A M.") && normalized.contains("P M."))
    #expect(KokoroText.prepare(prepared) == prepared)
  }

  @Test("Ambiguous text and invalid clock forms remain unchanged")
  func untouched() {
    let text = "I AM here at 13:45 a.m. or 11:99 p.m.; GB, 5173, 2.5x, a.m., https://a.m., M11:45 a.m. and x_11:45 a.m."
    #expect(KokoroText.prepare(text) == text)
  }
}
