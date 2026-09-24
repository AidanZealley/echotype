import EchoTypeCore
import Foundation
import Testing

@Test("A partial superseded by a later partial never reaches the committed text")
func interimTextIsNeverCommitted() throws {
  var assembler = TranscriptAssembler()
  try apply(
    [
      Fixture.created,
      Fixture.partial("tan stock"),
      Fixture.partial("tanstack is", isFinal: true),
    ],
    to: &assembler
  )

  // `is_final` on its own settles the run for display but commits nothing.
  #expect(assembler.text == "")
  #expect(assembler.settled == "tanstack is")
  #expect(assembler.provisional == "")

  try apply([Fixture.partial("tanstack is great", speechFinal: true)], to: &assembler)

  // The rewritten hearing is gone.
  #expect(assembler.text == "tanstack is great")
  #expect(assembler.settled == "tanstack is great")
}

@Test("Settled runs build up an utterance that its speech_final replaces rather than repeats")
func settledRunsComposeTheUtterance() throws {
  var assembler = TranscriptAssembler()
  // The recorded shape of one utterance: each partial carries only the run since the last
  // `is_final`, and the `speech_final` frame resends the whole utterance.
  try apply(
    [
      Fixture.created,
      Fixture.partial("meet on the fourth"),
      Fixture.partial("meet on the 4th", isFinal: true),
      Fixture.partial("at ten"),
    ],
    to: &assembler
  )
  #expect(assembler.settled == "meet on the 4th")
  #expect(assembler.provisional == "at ten")

  try apply([Fixture.partial("at 10:00", isFinal: true)], to: &assembler)
  #expect(assembler.settled == "meet on the 4th at 10:00")
  #expect(assembler.provisional == "")

  try apply(
    [
      Fixture.partial("meet on the 4th at 10:00", isFinal: true, speechFinal: true),
      Fixture.partial("bring"),
    ],
    to: &assembler
  )
  #expect(assembler.text == "meet on the 4th at 10:00")
  #expect(assembler.settled == "meet on the 4th at 10:00")
  #expect(assembler.provisional == "bring")
}

@Test("speech_final segments accumulate in order")
func segmentsAccumulateInOrder() throws {
  var assembler = TranscriptAssembler()
  try apply(
    [
      Fixture.created,
      Fixture.partial("install pnpm"),
      Fixture.partial("install pnpm", speechFinal: true),
      Fixture.partial("then add shadcn", speechFinal: true),
      Fixture.partial("and wire up zustand", speechFinal: true),
      Fixture.done,
    ],
    to: &assembler
  )

  #expect(assembler.text == "install pnpm then add shadcn and wire up zustand")
}

@Test("finalize resolves a trailing partial into the final text")
func finalizeResolvesTrailingPartial() throws {
  var assembler = TranscriptAssembler()
  try apply(
    [
      Fixture.created,
      Fixture.partial("open the settings pane", speechFinal: true),
      Fixture.partial("and paste the"),
    ],
    to: &assembler
  )
  #expect(assembler.text == "open the settings pane")

  // What `finalize` produces: the trailing partial comes back as one more speech_final segment.
  try apply([Fixture.partial("and paste the key", speechFinal: true)], to: &assembler)

  #expect(assembler.text == "open the settings pane and paste the key")
}

@Test("Events arriving after audio.done still count")
func eventsAfterAudioDoneAreAccumulated() throws {
  var assembler = TranscriptAssembler()
  try apply(
    [
      Fixture.created,
      Fixture.partial("first half", speechFinal: true),
      // Everything from here arrives after the client sent `audio.done`.
      Fixture.partial("second"),
      Fixture.partial("second half", speechFinal: true),
      Fixture.done,
    ],
    to: &assembler
  )

  #expect(assembler.text == "first half second half")
}

@Test("A session that hears nothing produces no text")
func emptySessionProducesNoText() throws {
  var assembler = TranscriptAssembler()
  try apply(
    [
      Fixture.created,
      Fixture.partial(""),
      Fixture.partial("", speechFinal: true),
      Fixture.done,
    ],
    to: &assembler
  )

  #expect(assembler.text == "")
  #expect(assembler.provisional == "")
}

@Test("A partial decodes its text, its words and its flags")
func partialDecodesItsPayload() throws {
  let event = try STTEvent.decode(
    Fixture.partial(
      "hello there",
      words: [("hello", 0.1, 0.4), ("there", 0.4, 0.7)],
      isFinal: true,
      speechFinal: true
    )
  )

  // `words` rides on every `is_final` frame, and every `speech_final` frame is one, so a word
  // shape the decoder rejects would throw away exactly the frames the transcript is built from.
  #expect(
    event
      == .partial(
        STTEvent.Partial(
          text: "hello there",
          words: [
            STTEvent.Word(text: "hello", start: 0.1, end: 0.4),
            STTEvent.Word(text: "there", start: 0.4, end: 0.7),
          ],
          isFinal: true,
          speechFinal: true
        )
      )
  )
}

@Test("An unrecognised event type is ignored rather than failing the session")
func unknownEventTypeIsIgnored() throws {
  #expect(try STTEvent.decode(#"{"type":"transcript.speculative"}"#) == nil)
}

@Test("transcript.done commits a tail that finalize resolved without speech_final")
func doneCommitsTheTrailingInterim() throws {
  var assembler = TranscriptAssembler()
  try apply(
    [
      Fixture.created,
      Fixture.partial("open the settings pane", speechFinal: true),
      // `finalize` resolves the tail with `is_final` alone, so nothing commits it before `done`.
      Fixture.partial("and paste the key", isFinal: true),
      Fixture.done,
    ],
    to: &assembler
  )

  #expect(assembler.text == "open the settings pane and paste the key")
  #expect(assembler.provisional == "")
}
