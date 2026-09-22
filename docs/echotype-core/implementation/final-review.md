# EchoTypeCore whole-feature review

Status: accepted. The branch is complete and the corrections below are committed with this record.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and
the approved specification. Inspect the accepted handoffs, but review the combined diff
and surrounding code independently.

Audit:

- Whether the specification's "What is tested where" list is actually covered, and
  whether anything claimed as tested is only asserted trivially.
- The seams between the converter, the client, the assembler and the session machine.
  Look for duplicated state, particularly transcript text held in two places.
- Dependency direction. Nothing in `EchoTypeCore` may reach toward a macOS layer.
- The Foundation-only rule, across every file.
- Test quality over test count. Tests coupled to internal field names, permutation
  tests that assert nothing a user would notice, and ceremonial smoke tests are
  findings, not coverage.
- Speculative machinery. Extension points, protocols with one conformer that no
  acceptance criterion needed, and configuration nobody sets.
- Whether workstream 3's findings were actually applied to workstream 4, or merely
  recorded.
- Whether the documents agree with the code, and whether recorded drift is real.

## Initial whole-feature review

- Reviewer: fresh whole-feature review agent, independent of every workstream agent.
- Branch, base, and reviewed head: `feat/echotype-core`, base `2c57765`, head `93e09de`.
  Reviewed the combined diff `2c57765..HEAD` and the surrounding code.
- Verification run: on a clean tree at `93e09de`. `swift build` clean in 1.9s.
  `swift test --disable-xctest` green, 37 tests in one suite, exit 0; the live integration
  test is skipped with `XAI_API_KEY` unset, as designed. `swift-format lint --recursive
  Sources Tests` silent, exit 0. The live tests were not run. One behaviour below was
  confirmed by running a throwaway executable in `/tmp` against the built library rather
  than by reading alone; no file in this repository was edited.

- Acceptance-criteria audit:

  The specification's "What is tested where" list, item by item.

  **Transcript assembly against recorded event streams.** Covered, and well.
  `TranscriptAssemblerTests.swift` runs every case the specification names through the real
  decoder: a partial superseded by a later one (`:5`), several `speech_final` segments
  (`:27`), `finalize` resolving a trailing partial (`:45`), events after `audio.done`
  (`:64`), and an empty result (`:82`). Nothing here is a smoke test.

  **The session machine with an injected clock.** Covered. Ten tests in
  `SessionMachineTests.swift` map onto the listed cases, and they are discriminating rather
  than ceremonial: `quietPausesAndSpeechResumes` (`:200`) feeds an empty partial mid-silence,
  so an implementation that counted a partial's arrival as activity fails it rather than
  passing by accident. `pauseCyclesAccumulateText` (`:220`) includes the duplicate
  `is_final`/`speech_final` frame pair workstream 3 observed, which is the right thing to
  pin. No test sleeps, polls or yields; every timeout runs through `TestClock`. "Stop with
  no audio" is covered by `triggerBeforeTheSessionIsReady` (`:296`) only in the sense that no
  audio was ever handed over, which I think is the honest reading of that line.

  **Audio conversion.** Covered. `AudioConverterTests.swift` asserts the rate ratio (`:19`),
  chunked output matching whole-buffer output over deliberately uneven buffers including a
  single frame (`:28`), clipping and non-finite samples (`:65`), byte order (`:91`), and a
  ramp that pins interpolation phase (`:80`). The ramp test is the one that would catch a
  resampler that quietly picks the nearest sample.

  **Query string construction, including the 100 keyterm and 50 character caps.** Covered by
  `STTConnectionTests.swift:10` and `:30`.

  **Settings and Keychain-adjacent serialisation round trips.** Not covered, and there is
  nothing to cover: `Settings` has no `Codable` conformance and no test file. See Required 4.

  Beyond the list: dependency direction and the Foundation-only rule both hold.
  `grep -rn "^import"` over `Sources` and `Tests` returns Foundation, EchoTypeCore and
  Testing only, plus the single `FoundationNetworking` import behind `#if
  canImport(FoundationNetworking)` in `URLSessionWebSocketTransport.swift:3-7`, which is the
  one file that constructs a real socket. Nothing in `EchoTypeCore` names a macOS type;
  `Settings.Hotkey` stores a raw keycode with `kVK_ANSI_D` mentioned only in a comment
  (`Settings.swift:23`), which is exactly the right side of that line.

  Workstream 3's findings did reach workstream 4 as code, not only as prose. `isSpeech`
  (`SessionMachine.swift:235-238`) keys off non-empty text or `speech_final`, which is the
  observed signal rather than the specification's wrong one. No timing anywhere is written
  against 2000ms. Nothing relies on the assembler's `done` fallback that workstream 3 warned
  would commit a fragment. The one workstream 3 finding that did not land is the missing
  `STTEvent.Word` coverage, which workstream 3 recorded as a known gap and handed to this
  review; it is still open. See Required 2.

  Seams and duplicated state. Transcript text lives in exactly one place, the assembler
  inside `STTClient`, and `SessionMachine` reaches it only through `client.text` and the
  client task's return value. The relay is a real cost but the cheaper alternative is worse,
  and workstream 4 argued that explicitly. What is duplicated is not state but decoding: both
  `SessionMachine.readUntilEnd` and `STTClient.run` decode every frame, and they disagree
  about what a failed decode means. That disagreement is Required 1.

  Speculative machinery: very little. `SessionClock` has two conformers and criterion 11
  needs it. `WebSocketTransport` has three. `Settings` carries fields no core code reads, but
  the specification names each one and workstream 1 froze it as the single source of
  tunables, so that is a contract rather than speculation.

- Required findings by owner:

  **Required 1 (`Sources/EchoTypeCore/SessionMachine.swift:195`, with
  `Sources/EchoTypeCore/STT/STTClient.swift:33`). One undecodable frame silently truncates
  the transcript and the session still reports success.** The session swallows a decode
  failure with `try?` and carries on; the client rethrows it and its task dies. Nothing tells
  the session the client is gone, so the relay keeps filling a stream nobody reads, the
  overlay keeps showing `listening` and `paused` off the session's own decoding, and
  `finalText()` falls back to `client.text` (`:312-316`), which froze at the bad frame.

  Failure scenario, confirmed by running it: a session receives `transcript.created`, a
  `speech_final` carrying "first sentence", one frame that is not decodable JSON, then a
  `speech_final` carrying "second sentence spoken after the bad frame". The user presses
  Opt+D and the machine returns `insert("first sentence")`. Everything after the bad frame is
  gone, the outcome is a clean insert rather than a failure, and the overlay has nothing to
  show the user. A non-JSON frame is not hypothetical: `URLSessionWebSocketTransport.swift:44-46`
  hands any binary frame through as a UTF-8 string, and a server-side field change of the kind
  that already bit this project once (`words`, `text` versus `word`) produces exactly this
  shape. Losing the tail of a minute of dictation without saying so is the outcome the
  specification's socket-failure rule exists to prevent.

  **Required 2 (`Tests/EchoTypeCoreTests/STTFixtures.swift:10-15`). Nothing in the committed
  suite constructs or decodes an `STTEvent.Word`.** `Fixture.partial` emits no `words` key and
  `grep -rn "Word" Tests` returns nothing. The plan's decision log names this as a known gap
  left for the final review, so it is mine to raise rather than to defer again.

  Failure scenario: the key name or shape of a word object drifts, as it already did. Every
  `is_final` frame carries `words`, and every `speech_final` frame is an `is_final` frame, so
  `decode` throws on precisely the frames the transcript is built from. The first live session
  lost 8 of 28 partials that way and the whole suite stayed green. With Required 1 unfixed
  the same defect now truncates silently instead of throwing, which makes the missing test
  worse than it was. One `words` argument on `Fixture.partial` and one expectation closes it.

  **Required 3 (`Sources/EchoTypeCore/SessionMachine.swift:121`). No transcript text crosses
  the seam while a session is running, so the overlay the specification describes cannot be
  built on this core.** `SessionMachine` owns the socket exclusively and exposes `states`,
  `run`, `send`, `trigger` and `cancel`. The text appears only in the outcome, after the
  session has ended. The specification wants the overlay to show partials as they arrive, with
  interim dimmed and `is_final` text solid, and calls that the thing "that lets the user notice
  a misheard term and cancel rather than paste something wrong". Comments in the code already
  claim this works: `TranscriptAssembler.swift:15-16` says the interim is "For display only,
  which is what the overlay renders dimmed", and `STTEvent.swift:18-19` says `isFinal` is "what
  the overlay uses to render solid rather than dimmed text". Neither value is reachable from
  outside.

  Failure scenario: the overlay milestone starts, finds the only live signal is a six-case
  state enum, and either reopens the accepted session machine or opens a second read of the
  same socket. The second option double-decodes frames and cannot work at all, since a
  WebSocket message goes to one reader. The fix is small if it is made now, for example
  yielding the committed and interim text alongside each state, or a second stream beside
  `states`. If the lead would rather let the overlay milestone design that seam, this becomes
  a documented next-milestone item and the two comments above should stop claiming otherwise.

  **Required 4 (`docs/echotype-core/implementation/plan.md` decision and drift log, with
  `Sources/EchoTypeCore/Settings.swift`). A line of the specification's "What is tested where"
  is unmet and unrecorded.** "Settings and Keychain-adjacent serialisation round trips" is
  listed as testable on Linux and is where the real bugs live. `Settings` has no serialisation
  at all and no test file. Workstream 1's packet made persistence a non-goal, which is a
  reasonable scope call, but the difference never reached the drift log, so both documents
  read as if the specification's list is satisfied.

  Failure scenario: the macOS milestone invents its own `UserDefaults` encoding for `Hotkey`
  and `keyterms` with no round-trip test behind it, and a keycode or modifier mapping bug
  surfaces as a hotkey that silently stops firing after an upgrade, which the specification
  already names as its most likely class of mystery failure. Either record the drift in one
  line or give `Settings` a `Codable` conformance and one round-trip test.

- Optional observations:
  1. Every frame is decoded twice, once in `SessionMachine.readUntilEnd`
     (`SessionMachine.swift:195`) and once in `STTClient.run` (`STTClient.swift:33`). Whatever
     shape Required 1's fix takes, decoding once and passing the event across the relay would
     remove the duplication along with the divergence.
  2. `STTEvent.Word.confidence` (`STTEvent.swift:42`) is written by nobody and read by nobody,
     and workstream 3 confirmed the endpoint never sends it in 30 frames. Keeping it was a
     recorded decision, so this is only a note: it is two lines to delete and nothing depends
     on it.
  3. `STTError.payloadTooLarge` and `.downloadFailed` (`STTEvent.swift:118-123`) are batch
     endpoint statuses. Neither can reach a streaming handshake, and
     `documentedStatusesMapToDistinctErrors` (`STTClientTests.swift:145`) is a table that
     restates the switch it tests. Harmless, and the cheapest test in the suite, but it is
     coverage of a mapping rather than of behaviour.
  4. `apiKeyIsABearerToken` (`STTConnectionTests.swift:51`) asserts one line of string
     interpolation against itself. It would not survive a review on its own merits.
  5. `ScriptedTransport.send(binary:)` discards frames (`SessionMachineTests.swift:50`), so
     nothing at the session level shows audio still streaming while paused. Workstream 4
     triaged this and declined it because the honest test is racy and the weak one is ceremony.
     I agree with that call and repeat it only because it is the one line of the packet's scope
     with no test behind it.

- Questions:
  1. Workstream 4 promoted "an unsolicited `transcript.done` must not commit" and changed the
     ending's classification, but `settle` still emits `inserting` whenever there is text
     (`SessionMachine.swift:320-322`), and the specification tells the macOS layer to insert
     the text carried by a failure. So the text still lands in the editor; only the label
     changed. The closure review says this plainly, and the plan's drift entry reads as if the
     commit was prevented. Is the intended behaviour that the text is inserted with an error
     shown alongside, as for a dropped socket, or that an untriggered `done` inserts nothing?
     The wording in the drift log should say which.
  2. The specification's silence detection is still wrong at lines 85-87 and 382-385, and the
     code deliberately does not implement it. That has been Aidan's call since workstream 3,
     unowned between workstream 5 and this review. Is this branch meant to land with the
     specification contradicting the code, or should the final-review commit carry the wording
     fix?
  3. The observed endpointing boundary, 2.73 to 2.80s from the last reported word, lives only
     in workstream 3's record. The specification's "Connection parameters" section still says
     nothing about it. Should it, given anything written against 2000ms is a second wrong?

- Verdict: **Changes required.** Four Required findings, one of them a confirmed correctness
  defect that loses transcript text without telling anyone. The rest of the branch is in good
  shape: the tests are behavioural rather than field-coupled, there is almost no speculative
  machinery, the Foundation-only and dependency rules hold cleanly, and workstream 3's
  observations really were built into workstream 4 rather than filed away.

## Lead triage

- Accepted findings and owners: three corrections, all to one fresh implementation agent
  owning `SessionMachine.swift`, two comments and `Tests/`.

  **Required 1, accepted.** I reproduced the reviewer's reading from the source before
  accepting it: `readUntilEnd` swallowed the decode failure with `try?` while `STTClient.run`
  rethrew it, so the client task died unnoticed, the state stream kept reporting a healthy
  session, and `finalText()` fell back to a `client.text` that had stopped growing. A
  truncation reported as a successful insert is the outcome the specification's
  socket-failure rule exists to prevent. Directed fix: an undecodable frame ends the session
  the way a dropped socket does, carrying whatever was finalised as `failed(text:error:)`,
  with the bad frame not passed on to the client. That removes the divergence rather than
  papering over it, which is why I did not accept a second error channel or a recovery path.

  **Required 2, accepted.** The plan's decision log hands this gap to the final review by
  name, so it was mine to close rather than defer again. `Fixture.partial` now emits `words`
  in the live shape and the decode test asserts real `STTEvent.Word` values, so a recurrence
  of the `text` versus `word` defect fails the suite instead of reaching a paid session.

  **Required 3, accepted in part.** The two comments now describe their fields instead of
  asserting an overlay wiring that does not exist. See the rejection below for the API half.

  **Required 4, accepted as drift.** Recorded in the plan's decision and drift log rather
  than implemented; see below.

- Rejected findings and reasons:

  **Required 3's API half, rejected.** The reviewer is right that no live transcript text
  crosses the seam, and wrong that this branch should fix it. Designing that seam now means
  guessing what the overlay needs from the same review brief that asks me to reject
  extension points no acceptance criterion needed. The overlay is a later milestone with its
  own requirements, including a level meter and dimmed interim text; it will design the seam
  against those. The real defect was the two comments claiming the work was already done,
  and those are fixed. Recorded in the plan as a known gap so the overlay milestone starts
  from it rather than rediscovering it.

  **Required 4's implementation half, rejected.** Giving `Settings` a `Codable` conformance
  in the core would be serialisation written for a `UserDefaults` and Keychain layer that
  does not exist yet, guessing at an encoding the macOS milestone owns. Workstream 1 scoped
  persistence out deliberately. The reviewer's actual finding is that the scope call never
  reached the drift log, and that is what I fixed.

- Deferred optional observations: all five.
  1. Double decoding. Required 1's fix removes the divergence, which was the defect. Removing
     the duplication needs the relay to carry decoded events, and the `WebSocketTransport`
     seam it would change is named in the specification and frozen by workstream 2. Not worth
     reopening a frozen contract for a second `JSONDecoder` pass over a frame at 1 Hz.
  2. `Word.confidence`. Keeping it was a recorded workstream 3 decision and the plan already
     warns workstream 4 not to expect it populated.
  3 and 4. `documentedStatusesMapToDistinctErrors` and `apiKeyIsABearerToken` are thin, and
     I agree they are closer to ceremony than coverage. Deleting accepted tests from two
     settled workstreams buys a marginally tidier suite and risks nothing useful either way,
     so it does not earn a place in a correctness commit.
  5. Audio streaming while paused. Workstream 4 declined it because the honest test is racy
     and the weak one is ceremony. The reviewer agrees. So do I.

- Drift requiring user decision: two items, both wording in the approved specification, both
  already Aidan's call and both recorded in the plan. The silence detection at lines 85-87
  and 382-385 is false as written and the code deliberately implements the observed
  behaviour instead. The observed 2.73-2.80s endpointing boundary lives only in workstream
  3's record while "Connection parameters" still reads as if 2000ms were the boundary.
  Neither blocks this branch: the code is right and the drift is logged. Editing an approved
  product document is not a review lead's decision, so both carry forward to Aidan.

## Focused closure

- Reviewed head: `feat/echotype-core` at `93e09de` with the corrections uncommitted in the
  working tree. Reviewed `git diff` plus untracked files; six files changed, three in
  `Sources` and three in `Tests`, with no untracked source or test file. `plan.md` is
  unchanged, which matters below.

  Verification, on the working tree: `swift build` clean in 1.9s. `swift test
  --disable-xctest` green, 38 tests in one suite, exit 0, one more than the 37 at `93e09de`.
  `swift-format lint --recursive Sources Tests` silent, exit 0. The live tests were not run.
  Two mutations were run against a throwaway copy of the repository in `/tmp`, since the
  corrections are only worth as much as the tests that hold them; no file in this repository
  was edited except this section.

- Finding outcomes:

  **Required 1, fixed.** `SessionMachine.readUntilEnd` (`:199`) now decodes with `try`
  inside the loop's existing `do`, so a frame the decoder rejects unwinds to the same
  `catch` a dropped socket reaches and returns `.failed(error)`. The bad frame never reaches
  `relay.deliver`, so the client no longer throws on it: it runs to `relay.finish()` and
  returns the text it had committed, which `finalText()` carries into
  `failed(text:error:)`. A decoding error is not an `STTError`, so `SessionError.init` maps
  it to `.socket`, which is the ending the lead directed. The divergence the finding named
  is gone in both directions: session and client now agree that an undecodable frame is
  fatal, and agree that an unrecognised `type` is not.

  The other endings still hold, checked one by one against the suite and the code.
  `STTEvent.decode` returns `nil` rather than throwing for a `type` it does not recognise
  (`STTEvent.swift:94-96`), and the `if let` skips it and still relays it, so an endpoint
  that grows an event does not end a session; `unknownEventTypeIsIgnored`
  (`TranscriptAssemblerTests.swift:128`) pins that at the decoder, which is where the
  behaviour lives. Every other ending is unchanged code reached through unchanged paths: a
  clean trigger and finalise, cancel while listening and while paused, an unsolicited
  `transcript.done`, a server `error` event, a transport failure, the hard cap, and the
  silence pause and resume cycle all still pass, including the empty-transcript and
  not-yet-created cases. Nothing in the fix touches `observe`, `reschedule`, `conclude` or
  `settle`.

  The new test fails without the fix, for the right reason. Reverting `try` to `try?` in the
  `/tmp` copy and running `--filter undecodableFrameEndsTheSession` gives `expected a socket
  failure, got .insert("first sentence")`: exactly the truncation-reported-as-success the
  finding described, not a compile error, a hang or an unrelated assertion. The test is also
  honest about ordering rather than lucky: `ScriptedTransport.emit` only returns once the
  session reaches for the next frame or the transport ends, and the session never reaches
  for another frame after throwing, so the bad frame's `emit` returns only after `conclude`
  has set `ending` and called `close()`. The `trigger()` that follows is therefore always
  rejected, which is what makes `textFrames.isEmpty` a real assertion that no `finalize` was
  sent past the end of the session.

  **Required 2, fixed.** `Fixture.partial` emits a `words` array in the live shape, naming
  the word `text` and omitting `confidence` (`STTFixtures.swift:10-25`), and
  `partialDecodesItsPayload` (`TranscriptAssemblerTests.swift:99`) decodes it through the
  real `STTEvent.decode` and asserts two `STTEvent.Word` values. Mutating `Word` to expect
  `word` instead of `text`, which is the defect that reached a paid session, fails that test
  with `keyNotFound: Key 'word' not found ... Path: words[0]`. The same mutation also fails
  the Required 1 test, because the fixtures become undecodable and the session now ends as a
  failure: the two corrections reinforce each other exactly as the triage intended. The
  default empty `words: []` keeps every other fixture caller unchanged, so nothing else in
  the suite moved.

  **Required 3's comment half, fixed.** `TranscriptAssembler.swift:15-16` now says the
  interim is never inserted and exists so a caller can show what is being heard, and
  `STTEvent.swift:17-19` now says `isFinal` marks text that is settled but not yet
  committed. Neither claims a rendering that does not exist. `grep -rn overlay Sources`
  leaves five mentions in `SessionMachine.swift` and one in `Settings.swift`, and all six
  describe states or outcomes, which do cross the seam. No stale claim survives.

  **Required 4, not done, and Required 3's other half with it.** The triage records both as
  entries in `plan.md`'s decision and drift log: the `Settings` serialisation scope call for
  Required 4, and the overlay seam as a known gap for Required 3's rejected API half.
  `plan.md` is untouched in the working tree and its log still ends at workstream 4's
  `transcript.done` entry and the unbounded-`finalizing` gap. Neither row exists. The log
  also still carries workstream 3's "Known gap, left for the final review: nothing in the
  committed suite constructs or decodes an `STTEvent.Word`", which the tests above have now
  closed.

- Final simplification assessment: the corrections are the smallest shape that removes the
  defect. Required 1 is a two-character change plus the comment that explains why, and it
  deletes a divergence rather than adding a mechanism: no second error channel, no recovery
  path, no new state, no new field. Required 2 adds one defaulted argument to an existing
  fixture and expands one existing expectation, rather than a new test file or a new decoder
  test suite. Required 3 removes two false sentences and adds nothing. The suite grew by one
  test, and that test asserts a user-visible outcome rather than an internal field. There is
  nothing here to delete and nothing to pull back.

- Remaining blockers: one, documentation only. The two `plan.md` log rows the lead's own
  triage commits to are missing, so both rejections currently live only in this review file.
  That matters most for Required 3: the reason the API half was rejected is that the overlay
  milestone should start from a recorded gap instead of rediscovering it, and an unrecorded
  gap does not do that. Required 4's whole accepted remedy was the record, so with no row it
  is simply unaddressed. This is the lead's to write, not a reviewer's, and both rows follow
  from text already agreed in the triage above. No release-blocking code defect remains.

- Verdict: **Approved, subject to the two `plan.md` log rows.** All three code and comment
  corrections were made, are correct, and are held by tests that fail without them; build,
  tests and lint are clean, and none of the session's other endings regressed. The branch is
  ready to commit once the decision and drift log records the `Settings` serialisation scope
  call and the overlay seam gap.

## Completion record

- Recovery: the first final-review lead was terminated by an infrastructure failure after
  closure had run and recorded its section, and before it wrote any plan row or committed.
  This lead inherited a tree of six modified source and test files plus this file at head
  `93e09de`, which is exactly the state the closure section describes, so the review, triage
  and closure records are attributable and were reused rather than rerun. Their central claim
  was re-checked independently rather than taken on trust: reverting `try` to `try?` in
  `readUntilEnd` in a throwaway copy of the package under `/tmp` fails
  `undecodableFrameEndsTheSession` with `expected a socket failure, got .insert("first
  sentence")`, which is the truncation-reported-as-success the finding described. No file in
  this repository was edited for that check. The only step left unfinished was the lead's own:
  the two decision and drift log rows closure named as its remaining blocker, which are now
  written, along with two further rows covering the `STTEvent.Word` gap this review closed and
  reviewer Question 1.

- Final verification: on the working tree at head `93e09de` with the corrections uncommitted.
  `swift build` clean. `swift test --disable-xctest` green, 38 tests in one suite, exit 0, one
  more than the 37 at `93e09de`. `swift-format lint --recursive Sources Tests` silent, exit 0.
  The live integration test skips with `XAI_API_KEY` unset, as designed, and the live tests
  were not run here. Imports across `Sources` and `Tests` are Foundation, EchoTypeCore and
  Testing only, plus the single `FoundationNetworking` import behind `#if
  canImport(FoundationNetworking)` in the one file that constructs a real socket, so the
  Foundation-only rule and the dependency direction both hold.

- External validation pending: none for this branch. Gate G1 passed at workstream 3 and its
  key and recording stay outside the repository. Everything still unvalidated needs macOS and
  belongs to a later milestone: audio capture, the event tap, the overlay panel, pasteboard
  insertion and TCC behaviour.

- Specification drift: three items, all recorded in the plan's decision and drift log and none
  blocking this branch.

  New at this review: the specification lists "Settings and Keychain-adjacent serialisation
  round trips" under what is tested here, and `Settings` has no serialisation and no test.
  Workstream 1 scoped persistence out deliberately; the scope call had never reached the log.
  Writing a `Codable` conformance now would guess at an encoding the macOS `UserDefaults` and
  Keychain layer owns, so this is recorded rather than implemented.

  Carried forward and still needing Aidan, since editing an approved product document is not a
  review lead's decision: the specification's silence detection at lines 85-87 and 382-385 is
  false as written and the code deliberately implements the observed behaviour instead, and
  "Connection parameters" still reads as if `endpointing=2000` were the boundary when the
  measured boundary is 2.73-2.80s from the last reported word.

  Also recorded, though not drift: no live transcript text crosses the session seam, so the
  overlay milestone must design that seam rather than assume it exists.

- What live protocol validation changed, if anything: a great deal, and it reached workstream 4
  as code rather than as prose. The specification's pause detector was written from
  documentation and is wrong against the real endpoint: partials keep arriving at about 1 Hz
  with empty text throughout a silence, and nothing arrives at all for the two to three seconds
  the endpoint spends deciding where an utterance ends, so "no new partials means silence" sees
  activity during silence and silence during speech. `SessionMachine.isSpeech` keys off a
  partial with non-empty text or a `speech_final` instead, and
  `quietPausesAndSpeechResumes` pins it. `endpointing=2000` is a floor rather than a boundary,
  so nothing in the code is timed against 2000ms. `transcript.done` comes back empty, with
  `finalize` resolving the tail into a further `speech_final` first, so nothing relies on the
  assembler's `done` fallback that would otherwise commit a fragment. And the live session
  exposed a real defect in a frozen contract: `STTEvent.Word` names the word `text`, not `word`,
  which had been throwing away 8 of 28 partials while the whole suite stayed green. That decode
  path is now covered by a test that fails on the same mutation.
