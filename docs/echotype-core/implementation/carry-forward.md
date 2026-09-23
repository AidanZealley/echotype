# EchoTypeCore carry-forward

Status: open. Written at the close of the EchoTypeCore workflow on 2026-09-22.

Everything the EchoTypeCore branch left for someone else to decide. The workflow's own
records are complete and closed; this file exists because some of what they recorded
outlives them.

Each item says what to re-check once [the macOS spike
branch](../../spike-macos/implementation/README.md) merges. That merge is the point at
which several of these stop being hypothetical, and a few may disappear entirely,
because the layer that owns the decision will exist.

The evidence behind every item is in the plan's decision and drift log. This file
points at decisions rather than restating them.

## Index

| # | Item | Owner | Survives the merge? |
|---:|---|---|---|
| 1 | Silence detection is wrong in the specification | Aidan | Yes. Code and specification disagree on purpose until edited |
| 2 | `endpointing=2000` reads as a boundary | Aidan | Yes |
| 3 | `Settings` serialisation is listed as tested and is not | Aidan, then the macOS settings milestone | Yes |
| 4 | `Package.swift` conflicts between the two branches | Whoever merges | No. Resolved by the merge itself |
| 5 | No live transcript text crosses the session seam | Overlay milestone | Probably. Depends what the overlay needs |
| 6 | Nothing bounds the wait after `finalize` | macOS session supervision | Probably |
| 7 | `confidence` is never populated | macOS consumers | Yes, as a constraint rather than a task |
| 8 | Chunk cadence belongs to the capture layer | macOS capture milestone | Likely resolved by the spike |
| 9 | Insertion on an unsolicited `transcript.done` | macOS insertion layer | Likely resolved by the spike |
| 10 | WebSocket support on the Linux machine | Environment | Yes, while this machine is used |
| 11 | Endpointing timings were measured on digital silence | Whoever tunes the threshold | Yes |

## Specification edits, which are Aidan's alone

A review lead cannot edit an approved product document, so these were recorded and left.
Items 1 and 2 are why the specification and the code currently disagree on purpose.

### 1. "No new partials means silence" is false

Lines 85-87, restated for the `listening` and `paused` transition at lines 382-385.

The rule assumes partials stop during a silence. Against the real endpoint they do not.
Partials keep arriving at roughly 1 Hz with `"text":""` throughout a silence, and nothing
arrives at all for the two to three seconds the endpoint spends deciding where an
utterance ended. The documented detector therefore sees activity during silence and
silence during speech, wrong in both directions.

`SessionMachine.isSpeech` implements the observed signal instead: a partial with
non-empty text, or a `speech_final`. `quietPausesAndSpeechResumes` pins it.

After the merge: unchanged. This is a wording fix in the specification, and the code is
already correct. Nothing in the macOS branch can resolve it.

### 2. "Connection parameters" reads as if `endpointing=2000` were the boundary

The measured boundary is 2.73 to 2.80 seconds from the endpoint's own last reported word
`end`, and about 3.0 seconds of wall clock to having the `speech_final` frame in hand.
Measured across two acoustically different pauses, agreeing to 75ms.

The specification never claims a 2000ms boundary, so this is a clarification rather than
a contradiction. It matters because any timing written against 2000ms is a second out.
Nothing in the current code is timed against it.

After the merge: unchanged, and worth doing before anyone writes overlay timing.

### 3. `Settings` serialisation is listed under what is tested here

The specification lists "Settings and Keychain-adjacent serialisation round trips" among
what this package tests. `Settings` has no serialisation and no test.

Workstream 1 scoped persistence out deliberately, but the scope call never reached the
drift log, so both documents read as though the list were satisfied. Writing a `Codable`
conformance in this package now would guess at the `UserDefaults` and Keychain encoding
the macOS layer owns.

The round trip is still where the real bugs live. Whoever writes that encoding owes it a
test, or a hotkey that silently stops firing after an upgrade surfaces as a mystery.

After the merge: re-read this one first. If the spike already persists settings, the
owner exists and this becomes a concrete task on that code rather than an open question.

## Resolved by the merge

### 4. `Package.swift`

Both branches create it. This branch declares `EchoTypeCore` and `EchoTypeCoreTests`
only, with no conditional macOS app target, because the app target does not exist here.
The specification's illustrative snippet shows the conditional target and describes the
merged manifest, which is correct for the result and premature on this branch.

After the merge: the reconciled manifest should look like the specification's snippet.
This item then closes.

## Deferred to the macOS milestones

These are deliberate omissions, not oversights. Each was left because designing it here
meant guessing at requirements the macOS layer owns.

### 5. No live transcript text crosses the session seam

`SessionMachine` exposes states and the final outcome. Committed and interim text are
reachable only inside it, so nothing can render a live transcript today.

One constraint binds whoever designs that seam: it must extend `SessionMachine` rather
than open a second read of the socket, because a WebSocket message goes to exactly one
reader.

After the merge: check what the overlay actually needs, including the level meter and
dimmed interim text, and design the seam against that. If the spike's overlay turns out
not to render transcript text at all, this item shrinks or closes.

### 6. Nothing bounds the wait for `transcript.done` after `finalize`

A hung endpoint leaves a session in `finalizing` indefinitely.

Workstream 3 saw `done` arrive within 10ms and the server close two seconds later, so a
timeout here would be machinery for a failure never observed. Session supervision belongs
to the layer that owns the overlay and can tell the user something went wrong.

After the merge: if the spike has a supervision or timeout story, put this there. If it
does not, this stays open until the overlay milestone.

### 7. `confidence` is never populated

`STTEvent.Word.confidence` survives on the type although the endpoint sent it in none of
30 frames. An unused optional that decodes correctly either way is not a defect the live
protocol exposed, which is the only licence workstream 3 had to touch a frozen contract.

After the merge: a constraint to honour, not a task. No macOS consumer should expect it
to be there.

### 8. Chunk cadence belongs to the capture layer

The roughly 100ms cadence is the `AVAudioEngine` tap's obligation, not `AudioConverter`'s.
The converter returns what is ready for the buffer it is handed, and `installTap` treats
buffer size as a hint rather than a guarantee.

After the merge: check the spike's capture code actually delivers that cadence. This is
the item most likely to be already settled by work on the other branch.

### 9. Insertion on an unsolicited `transcript.done`

A `transcript.done` arriving outside `finalizing` does not commit. It ends the session the
way a dropped socket does, as `failed(text:error:)` carrying whatever was finalised, and
the session still passes through `inserting` when there is text.

So the text still reaches the editor and the user keeps their dictation. What the rule
prevents is the macOS layer being handed a clean commit it never triggered, which is the
specification's rule that text reaches the target app only on an explicit trigger or the
hard cap.

After the merge: confirm the insertion layer inserts the text carried by a failure
alongside surfacing the error. If it does, this closes.

## Environment

### 10. WebSocket support on the Linux machine

Ubuntu 24.04's only libcurl is built without websockets, so `URLSessionWebSocketTask`
fails with `NSURLErrorDomain -1002` and no apt package fixes it. curl 8.11.1 built from
source with `--enable-websockets` lives at `~/.local/curl-ws`.

Any command that opens a real socket on this machine needs the prefix:

```bash
LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib swift test --disable-xctest
```

The loader's `no version information available` warning is benign. The workflow README
claims `URLSessionWebSocketTask` was verified on this machine without qualification,
which is false as written and cost workstream 3 an escalation to discover.

After the merge: irrelevant on macOS, and still true here.

### 11. Endpointing timings came from digital silence

The 2.73 to 2.80 second window was measured against a fixture whose pauses are inserted
digital silence, using public-corpus speech rather than Aidan's voice.

Digital silence is the easiest case a voice activity detector will ever get, so that
window is a floor. A real room floor may push the boundary later.

After the merge: once capture works on the Mac, re-measure against a real microphone in a
real room before tuning anything against these numbers. The ten second pause threshold has
comfortable margin either way, so this is precision rather than correctness.

## What is not here

Items the workflow closed rather than deferred are in the plan's decision and drift log
and in [final-review.md](final-review.md). The `STTEvent.Word` decode defect and its test
gap are both closed. Gate G1 passed. No escalation is open.
