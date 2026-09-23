# EchoType open items

Status: open. Reconciled 2026-09-23 from the two parallel workflows, once
`spike/macos-hotkey-paste` and `feat/echotype-core` met on one branch.

Everything both workflows left for someone else to decide. Neither workflow's own
records are open: both were accepted, and this is the residue that outlived them.

The two source lists were written independently, one per branch, and are replaced by
this file. The evidence behind every item is in the owning workflow's decision and drift
log, linked per item. This is the short list, not a third record.

Fourteen items. One closed on contact.

## Read these first

Three have a deadline rather than merely an owner.

- **O1** and **O4** are places where the code and the specification now disagree on
  purpose. Every day that stands, the specification is actively misleading.
- **O4** settles before build-order step 3 reuses `Inserter`, or the first reuse silently
  picks one of two contradictory readings.

## Closed by the merge

**`Package.swift` reconciliation.** Both branches created the file, each declaring only
its own target. Resolved in merge `0a2024c` along the design at `echotype-v1.md:366`:
`EchoTypeCore` plus tests unconditionally, `EchoTypeApp` appended behind `#if !os(Linux)`,
`platforms: [.macOS(.v26)]` kept and inert on Linux.

Verified on Linux only. `EchoTypeApp` compiling against the merged manifest is unproven
until `scripts/run.sh` runs on the Mac.

Not yet done, and deliberately: `EchoTypeApp` has no `dependencies: ["EchoTypeCore"]`,
because nothing in the app imports Core yet. One line, when the first import lands.

## Specification edits, which are Aidan's alone

A lead cannot edit an approved product document, so both workflows recorded and left
these. Six items, from both branches, and the reason this reconciliation was worth doing:
they are one job, not two.

### O1 "No new partials means silence" is false

From EchoTypeCore workstream 3. Lines 85-87, restated for the `listening` and `paused`
transition at 382-385.

The rule assumes partials stop during a silence. Against the real endpoint they do not.
Partials keep arriving at roughly 1 Hz with `"text":""` throughout a silence, and nothing
arrives at all for the two to three seconds the endpoint spends deciding where an
utterance ended. The documented detector sees activity during silence and silence during
speech, wrong in both directions.

`SessionMachine.isSpeech` already implements the observed signal: a partial with non-empty
text, or a `speech_final`. `quietPausesAndSpeechResumes` pins it. Only the wording is
outstanding.

### O2 "Connection parameters" reads as if `endpointing=2000` were the boundary

From EchoTypeCore workstream 3. The measured boundary is 2.73 to 2.80 seconds from the
endpoint's own last reported word `end`, and about 3.0 seconds of wall clock to having the
`speech_final` frame in hand. Two acoustically different pauses, agreeing to 75ms.

The specification never claims a 2000ms boundary, so this is a clarification rather than a
contradiction. It matters because any timing written against 2000ms is a second out.
Nothing currently is. See also O14, which says why these numbers are a floor.

### O3 `Settings` serialisation is listed under what is tested

From the EchoTypeCore final review. The specification lists "Settings and Keychain-adjacent
serialisation round trips" among what this package tests. `Settings` has neither
serialisation nor a test.

Workstream 1 scoped persistence out deliberately, but the scope call never reached the
drift log, so both documents read as though the list were satisfied.

Re-checked after the merge: still open, and the owner still does not exist. The spike is
127 lines across three files and touches no settings, no Keychain and no persistence.
Whoever writes that encoding owes it a test, or a hotkey that silently stops firing after
an upgrade surfaces as a mystery.

### O4 The specification contradicts itself on the pasteboard restore

From the macOS spike. Step 4 restores the previous pasteboard contents when `changeCount`
advanced by exactly one. The paragraph below it says the transcript stays on the pasteboard
either way. Both cannot hold.

The spike follows numbered step 4, and Aidan confirmed at gate G3 that his earlier clipboard
came back after Opt+D.

This one has a deadline. Settle it before build-order step 3 reuses `Inserter`, or the first
reuse picks a reading silently.

### O5 Certificate creation steps omit the trust step

From the macOS spike. The steps for creating the `EchoType Dev` certificate never mention
setting Code Signing to Always Trust. Without it, `security find-identity -v` hides the
identity and `scripts/run.sh` fails at signing with no obvious cause. It cost the spike a
round trip.

### O6 macOS 27 grants one permission, not two

From the macOS spike. On macOS 27.2 the event tap and the posted Cmd+V are covered by a
single "Device Control and Data Access" grant, attributed to EchoType itself. The
specification still describes separate Accessibility and Input Monitoring grants.

Two consequences:

- The permissions section should describe what macOS 27 actually asks for.
- The escape hatch `tccutil reset Accessibility com.aidanzealley.echotype` should become
  `tccutil reset All com.aidanzealley.echotype`. Only `reset All` was verified. Whether
  `reset Accessibility` still clears the macOS 27.2 grant is untested, so do not record the
  recommendation as proven.

Related: O11 is the code comment that names the old permission model.

## Deferred to named milestones

Deliberate omissions, not oversights. Each was left because designing it early meant
guessing at requirements another layer owns.

### O7 No live transcript text crosses the session seam

Owner: the overlay milestone. `SessionMachine` exposes states and the final outcome.
Committed and interim text are reachable only inside it, so nothing can render a live
transcript.

One constraint binds whoever designs that seam: extend `SessionMachine` rather than open a
second read of the socket, because a WebSocket message goes to exactly one reader.

Re-checked after the merge: still open. The spike has no overlay.

### O8 Nothing bounds the wait for `transcript.done` after `finalize`

Owner: macOS session supervision. A hung endpoint leaves a session in `finalizing`
indefinitely.

Workstream 3 saw `done` arrive within 10ms and the server close two seconds later, so a
timeout would be machinery for a failure never observed. Supervision belongs to the layer
that owns the overlay and can tell the user.

Re-checked after the merge: still open. The spike has no supervision story.

### O9 `confidence` is never populated

Owner: every macOS consumer, as a constraint rather than a task. `STTEvent.Word.confidence`
survives on the type although the endpoint sent it in none of 30 frames. An unused optional
that decodes correctly either way was not a defect the live protocol exposed, which was
workstream 3's only licence to touch a frozen contract.

Nothing should expect it to be there.

### O10 Chunk cadence belongs to the capture layer

Owner: the macOS capture milestone. The roughly 100ms cadence is the `AVAudioEngine` tap's
obligation, not `AudioConverter`'s. The converter returns what is ready for the buffer it is
handed, and `installTap` treats buffer size as a hint rather than a guarantee.

Re-checked after the merge: still open, contrary to the pre-merge guess that the spike would
settle it. The spike has no audio capture at all.

### O11 Hotkey comments name the old permission model

Owner: build-order step 3, when it rewrites this code.
`Sources/EchoTypeApp/HotkeyMonitor.swift` comments say "Accessibility not granted" and
"Surfaces the Accessibility prompt". The call really is the Accessibility trust check, so
the comments are right about the API and wrong about what the user sees, which is O6's
single grant.

A word or two. Deliberately deferred during the spike's final review.

### O12 Insertion on an unsolicited `transcript.done`

Owner: the macOS insertion layer. A `transcript.done` arriving outside `finalizing` does not
commit. It ends the session the way a dropped socket does, as `failed(text:error:)` carrying
whatever was finalised, and the session still passes through `inserting` when there is text.

The text still reaches the editor and the user keeps their dictation. What the rule prevents
is the macOS layer being handed a clean commit it never triggered, which is the
specification's rule that text reaches the target app only on an explicit trigger or the hard
cap.

Re-checked after the merge: still open, contrary to the pre-merge guess. `Inserter` exists but
nothing wires `SessionMachine` to it, so the behaviour has no consumer yet. Confirm the
insertion layer surfaces the error while still inserting the text a failure carries.

## Environment and measurement

### O13 WebSocket support on the Linux machine

Ubuntu 24.04's only libcurl is built without websockets, so `URLSessionWebSocketTask` fails
with `NSURLErrorDomain -1002` and no apt package fixes it. curl 8.11.1 built from source with
`--enable-websockets` lives at `~/.local/curl-ws`.

Any command that opens a real socket on that machine needs the prefix:

```bash
LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib swift test --disable-xctest
```

The loader's `no version information available` warning is benign.

`docs/echotype-core/implementation/README.md` still claims `URLSessionWebSocketTask` was
verified on that machine without qualification. That is false as written and cost workstream 3
an escalation to discover. Worth correcting if the workflow document is ever reused.

Irrelevant on macOS.

### O14 Endpointing timings came from digital silence

Owner: whoever tunes the pause threshold. The 2.73 to 2.80 second window in O2 was measured
against a fixture whose pauses are inserted digital silence, using public-corpus speech rather
than Aidan's voice.

Digital silence is the easiest case a voice activity detector will ever get, so that window is
a floor. A real room floor may push the boundary later.

Once capture works on the Mac, re-measure against a real microphone in a real room before
tuning anything against these numbers. The ten second pause threshold has comfortable margin
either way, so this is precision rather than correctness.

## Provenance

| Item | Source workflow | Original id |
|---|---|---|
| O1, O2 | EchoTypeCore workstream 3 | Core carry-forward 1, 2 |
| O3 | EchoTypeCore final review | Core carry-forward 3 |
| O4, O5, O6 | macOS spike | S1, S2, S3 |
| O7, O8, O12 | EchoTypeCore workstream 4 and final review | Core carry-forward 5, 6, 9 |
| O9, O10 | EchoTypeCore workstreams 1 and 3 | Core carry-forward 7, 8 |
| O11 | macOS spike | S4 |
| O13, O14 | EchoTypeCore workstream 3 | Core carry-forward 10, 11 |
| Closed | EchoTypeCore workstream 1 | Core carry-forward 4 |

Full evidence:

- EchoTypeCore: [plan.md](echotype-core/implementation/plan.md) decision and drift log,
  and [final-review.md](echotype-core/implementation/final-review.md).
- macOS spike: [plan.md](spike-macos/implementation/plan.md) decision and drift log, and
  [final-review.md](spike-macos/implementation/final-review.md).
