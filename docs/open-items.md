# EchoType open items

Status: open, two items left. Reconciled 2026-09-23 from the two parallel workflows and
worked through with Aidan the same day.

Twelve of the original fourteen are closed. What remains is two questions Aidan has not
decided yet, held here rather than guessed at.

## O2 How to describe `endpointing=2000` in the specification

The specification's Connection parameters section sets `endpointing=2000` and does not say
what the number does. Nothing in the code is timed against it, so this is a documentation
question, not a defect.

What workstream 3 measured against the live endpoint: the gap between a word ending and the
server declaring the utterance over was 2.73 to 2.80 seconds, not 2.00. Wall clock from the
last word to having the `speech_final` frame in hand was about 3.0 seconds. Two acoustically
different pauses agreed to within 75ms.

So `endpointing=2000` behaves as a floor the server will not go below, rather than the
boundary itself.

Folded in from what was a separate item: those numbers came from a fixture whose pauses are
inserted digital silence, using public-corpus speech. Digital silence is the easiest case a
voice activity detector will ever get, so 2.8 seconds is a lower bound and a real room may
push it later. Whatever wording lands should carry that caveat, or the number will be read as
more precise than it is.

Open question: whether to record the measurement at all, and if so where.

## O3 What to do about `Settings` serialisation

`docs/specs/echotype-v1.md:471` lists "Settings and Keychain-adjacent serialisation round
trips" under what EchoTypeCore tests. `Settings` has neither serialisation nor a test, so the
line is false today.

How it got there: workstream 1 scoped persistence out on purpose, but the scope call never
reached the drift log, so both documents read as though the list were satisfied.

Re-checked after the merge: the owner still does not exist. The merged app is 127 lines across
three files and touches no settings, no Keychain and no persistence.

The two ways out pull in opposite directions. Writing a `Codable` conformance now means
inventing the `UserDefaults` and Keychain encoding the macOS layer has not chosen, so the test
would assert the invention rather than the real format. Deleting the line makes the
specification honest immediately but leaves nothing recording that the round trip is where the
real bugs live: a hotkey that silently stops firing after an upgrade surfaces as a mystery.

Open question: delete the claim, or implement against a guessed encoding.

## Closed

Twelve items, resolved 2026-09-23 unless noted.

| Item | Resolution |
|---|---|
| `Package.swift` reconciliation | Done by merge `0a2024c`, along the design at `echotype-v1.md:366` |
| O1 Silence detection is false | Specification rewritten at both sites to the observed signal: a partial with non-empty text, or a `speech_final` |
| O4 Pasteboard restore contradiction | Specification reworded; the `changeCount` guard now describes two outcomes instead of claiming both |
| O5 Certificate trust step missing | Always Trust added to the signing steps, with the symptom it causes when skipped |
| O6 macOS 27 grants one permission | Permissions section rewritten for the single grant; escape hatch changed to `tccutil reset All` |
| O7 No live transcript text at the seam | Not built. The one lasting constraint is now a doc comment on `SessionMachine`: a WebSocket message goes to exactly one reader |
| O8 No timeout after `finalize` | Not built, deliberately. `done` arrived in 10ms and the server closed 2s later, so a timeout would be machinery for a failure never observed |
| O9 `confidence` never populated | Field deleted from `STTEvent.Word`. Unknown keys decode away, so it costs nothing to add back if the endpoint ever sends it |
| O10 Chunk cadence | Already discharged at `AudioConverter.swift:9-10` |
| O11 Hotkey comments name the old grant | Comments now distinguish the API, still the Accessibility trust check, from what the user sees |
| O12 Insertion on an unsolicited `transcript.done` | Already implemented and tested. The item only restated a requirement the specification already carries |
| O13 WebSocket support on the Linux machine | The EchoTypeCore workflow README no longer claims the transport was verified there, and carries the `LD_LIBRARY_PATH` prefix instead |

Full evidence:

- EchoTypeCore: [plan.md](echotype-core/implementation/plan.md) decision and drift log,
  and [final-review.md](echotype-core/implementation/final-review.md).
- macOS spike: [plan.md](spike-macos/implementation/plan.md) decision and drift log, and
  [final-review.md](spike-macos/implementation/final-review.md).
