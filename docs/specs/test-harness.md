# Test harness

Status: draft, 2026-10-03. Built alongside the [local models spike](../spikes/local-models/spec.md),
which is its first consumer. Implementation is not authorised by this document alone.

## Goal

Let agents verify EchoType's behaviour themselves instead of asking Aidan to repeat the
same manual checks. Automate everything that does not need a human. For what does,
prepare the check, collect the verdict in seconds and record the evidence.

The harness has four layers, each useful before the next exists: a recorded corpus, a
provider bench, an app driver and guided human sessions. A scenario catalogue and an
agent rule make them the default route for verification.

## Problem

Unit and fixture tests cover the core well, but most behaviour that matters to a user
is checked by hand on the Mac: provider quality, dictation into a real app, reading with
pause and resume, lifecycle edge cases, pill and Settings states, and permissions.
Agents request these checks repeatedly, often for the same things, and progress waits on
them. Decisions record many of them as done once, and [0007](../decisions/0007-known-gaps.md)
lists checks still verified only by reading.

| Kind | Examples | Route |
| --- | --- | --- |
| Provider quality | Keyterm spellings, cleanup edits, voice quality, accents | Corpus and bench |
| End-to-end flow | Dictation pasted into an app with the clipboard restored, reading a selection, MCP speech | App driver |
| Lifecycle | Rapid stop, stop while finalising, provider switch during setup, dictation then reading in quick succession | App driver |
| Visual | Pill phases, Settings status rows, both themes | App driver snapshots, judged by the agent |
| Human only | First-use permission prompts, preferred voice, Bluetooth headsets, unusual destination apps | Guided session |

## Boundaries

- The bench is a separate executable target. It never ships in the app bundle.
- App seams for the driver compile only in debug builds (`#if DEBUG`). Release builds
  cannot be driven or fed file audio. The driver targets the signed debug bundle that
  `scripts/run.sh` builds. Signed release checks remain a short guided session.
- Recordings of Aidan's voice stay outside git. Only manifests, reference texts and
  scenario code are committed.
- Calls to xAI cost money and send samples to xAI. The bench calls a paid provider only
  when explicitly asked, never by default.
- No scenario DSL, plugin system or generic test framework. Scenarios are plain Swift
  functions until their number shows a real need for more structure.

## Layer 1: corpus

The corpus is permanent test data, recorded once and replayed against every later
provider change, prompt edit or model swap.

[`Corpus/manifest.json`](../../Corpus/manifest.json) is committed. It lists the corpus
keyterms and every sample, each with an id, a kind and tags:

| Kind | Fields | Reference |
| --- | --- | --- |
| `dictation` | `source` (`recorded` or `synthetic`), the `prompt` Aidan follows, and a `script` for scripted clips. Natural clips are scenarios, such as "describe a bug and change your mind about its cause halfway". | `reference`: null until reviewed, then the transcript. Silence has an empty reference. |
| `cleanup` | `segments`: committed text in the order and at the seconds it arrives, written by hand or taken from a dictation. | `expected`: the correct cleanup, and `ambiguous` when more than one edit is reasonable. |
| `reading` | `text`, and `checks` naming the words or features under test. | The text itself. |

Expected cleanups only delete words, so each must be a subsequence of its segments'
words; the bench rejects a manifest where one is not. Scoring derives the deleted words
from the expected text rather than storing them separately.

Audio lives in `~/Library/Application Support/EchoTypeBench/audio/<id>.wav`, 16 kHz mono
Int16. Synthetic dictation is generated from a scripted sample with `say` and
`afconvert`, which the Apple live tests already use; Apple's transcriber produced a
complete transcript from such a file on 2026-10-03. Synthetic audio is valid for
lifecycle and end-to-end runs that only need speech to arrive, and lets the bench be
built and tested before any recording exists. It is never used for accuracy results.

Reference transcripts start as drafts. The agent drafts each from provider outputs and
their disagreements; Aidan corrects the draft. A sample counts as reviewed only after
that correction.

## Layer 2: bench

`EchoTypeBench`, an executable target depending on `EchoTypeCore`, runs corpus samples
through a `Provider`'s services using the public contracts. The existing integration
helpers (`WAVRecording`, `AudioConverter`) move into a place both the bench and tests can
use. Every command takes `--provider xai|apple|local` and writes raw JSONL into
`~/Library/Application Support/EchoTypeBench/runs/<run-id>/`, with a `run.json` recording
the Mac, OS, toolchain, source revision, provider and candidate selection.

| Command | Does | Records |
| --- | --- | --- |
| `corpus status` | Lists samples missing audio or a reviewed reference. | What to ask Aidan for. |
| `record <id>` | Shows the prompt, records until Return and saves the WAV. The first recording asks for the terminal's microphone permission. | The recording. |
| `synthesize` | Generates synthetic WAVs for scripted dictation samples. | Synthetic recordings. |
| `transcribe` | Feeds 100 ms chunks through a `LiveTranscriber`, at real-time pace for latency or `--fast` for accuracy. | Every event with its time, final text, first provisional and committed text, stop-to-final time, committed text that changed. |
| `cleanup` | Replays each sample's committed-text timeline through the real `Reviser` with `submit`, then `finish`. | `DictationTrace` revisions, stop-to-insert time, share of time spent revising, fallbacks. |
| `speak` | Pulls a `SpeechStream` as a real-time player would, with a pause partway. | First chunk time, gaps, real-time factor, audio generated while paused, the WAV. |
| `lifecycle` | Rapid stop, stop during inference, cancel during generation, close and join. | Cancellation latency and hangs. |
| `report` | Aggregates runs. | Markdown tables with p50/p95 and sample counts, plus the listening page. |

xAI runs read the key from `XAI_API_KEY`, as `LiveProtocolTests` does, rather than
EchoType's Keychain item. Apple's transcription, voice and cleanup all ran from
command-line processes on 2026-10-03 without permission prompts, so the bench can use
them directly.

Local candidates can be selected with `--candidate <service>=<name>`. This is a bench
argument, not a product setting; app builds still select candidates in one file.

Every run checks the contracts in [`Provider.swift`](../../Sources/EchoTypeCore/Providers/Provider.swift)
and records violations as failures: `.ready` first, committed text only grows, finished
after finish, chunks of at most 100 ms at one sample rate, bounded generation while
paused, and prompt cancellation.

A background sampler records `phys_footprint`, thermal state and system memory pressure
during every run. `powermetrics` needs root, so energy measurement is a guided step.

Scoring is automatic where the reference allows:

- Word error rate and keyterm accuracy against reviewed transcripts, using `Prose`'s
  word normalisation.
- Cleanup wrong deletions and missed edits, comparing the words a reply deleted with
  those the expected cleanup deletes. Both are subsequences of the input, so aligning
  each against it is enough. Ambiguous samples go to manual judgement.
- Read-aloud round trip: transcribe each generated reading and compare it with the source
  to catch skipped, repeated or invented words. It cannot hear heteronyms or prosody.

`report` writes a draft results document and a local HTML listening page. The page plays
each passage from every voice under shuffled labels and saves ratings as JSON, so voices
are judged blind.

## Layer 3: app driver

Three debug-only seams let the bench drive the signed debug app.

1. **Control channel.** Commands and events are `Codable` types in one debug-only file in
   `EchoTypeCore`, sent with distributed notifications as `SpeechDelivery` already does.
   Delivery between two separate unsigned command-line processes worked on 2026-10-03.
   The bench sends; the app handles. Commands: `dictate` with a WAV path, `stop`,
   `cancel`, `read` with text, `pause`, `resume`, `selectProvider` and `snapshot`.
2. **File audio.** A `dictate` command with a WAV path substitutes a file source for
   `AudioCapture`, streaming 100 ms chunks at real-time pace into the same chunk path.
   Everything after capture is production code. Device opening, Bluetooth profiles and
   microphone permission stay outside automated coverage.
3. **Event log.** The app appends JSONL to its Application Support directory: operation
   phases, pill phases, readiness changes, completed `DictationTrace`s, reading timings and
   errors. Reading timings include first audible audio, taken from `SpeechPlayer`'s
   existing output tap.

Scenarios run in one of two modes, because pasting needs keyboard focus and a
command-line process cannot reliably take it. On 2026-10-03 a window launched from the
terminal became key only while the terminal's app was frontmost; with another app in
use, macOS refused the activation. Taking focus would also disrupt Aidan's work.

- **Background**, the default. No focus is taken and nothing is audible: a `silent`
  option on `dictate` and `read` mutes the app's output while `SpeechPlayer`'s tap still
  measures playback. Dictation runs to its outcome and the scenario asserts on the
  event log and trace, including the text that would be inserted. The paste itself is
  covered by `ClipboardTests` and by foreground scenarios.
- **Foreground**, run only when Aidan says the Mac is free. The bench opens a small
  window with a text field, which a terminal-launched process can make key while the
  terminal is frontmost. It asserts on the field's text, the clipboard and the log.
  Reading the field directly needs no Automation permission, and the signed debug app
  keeps its existing Accessibility permission for pasting.
  The log records whether paste was confirmed at the caret or finished on the 400 ms
  fallback ([0020](../decisions/0020-pasteboard-insertion-and-selection-copy.md)), so
  a foreground run checks paste confirmation as well as the inserted text.

`snapshot` renders the pill or a Settings view to PNG inside the app, in a requested
appearance, with `ImageRenderer`. On 2026-10-03 this rendered layout, text and colour
but not the glass effect, and `cacheDisplay` rendered nothing. Snapshots check state
and layout; faithful glass appearance needs window capture with Screen Recording
permission, which stays a guided check.

The hotkey itself is not driven. `HotkeyAdapterTests` cover its handling; a real
keypress is a guided step when a change touches it.

## Layer 4: guided sessions

`bench session <name>` covers checks that need a human. It prepares the state, gives one
instruction at a time and takes a single keystroke per verdict, such as `y`/`n` or a
rating. It records traces, log events and snapshots alongside the answers and writes an
evidence file into the run directory. Agents read the evidence rather than asking for a
description.

Initial sessions: signed release check, first-use permission prompts, voice audition
using the listening page, energy measurement and Bluetooth input.

## Scenario catalogue and agent rule

Scenarios live in the bench, one Swift function each, named for the behaviour they
check, such as `dictate-into-field`, `read-pause-resume`, `provider-switch-during-setup`
and `stop-during-final-revision`. Each is tagged `automated` or `human`. `bench scenarios`
lists them; `bench run <name>` runs one.

Add this rule to `AGENTS.md` once the driver exists:

> Before asking Aidan for manual testing, run the matching automated scenarios. If none
> covers the behaviour and one is practical, add it. Ask for human checks only through a
> `human` scenario's guided session, and explain why automation cannot cover it.

The items in [0007](../decisions/0007-known-gaps.md) marked as verified only by reading,
and the signed-install Apple checks, are the first scenario backlog.

## Build order

Each step is usable before the next starts.

1. **Corpus and bench against xAI and Apple.** `corpus status`, `record`, `transcribe`,
   `cleanup`, `speak` and `report`. Record the corpus and review references. This gives
   provider baselines.
2. **Local candidates in the bench.** The local models spike runs its evaluation here.
3. **App seams, driver and about five scenarios** for the checks requested most often.
   The local provider's signed-app checks run through them.
4. **Guided sessions**, including the voice audition and signed release check.
5. **Catalogue and agent rule.** Convert the 0007 backlog.

## Completion criteria

- A provider change can be evaluated against the corpus with one command per service,
  producing paired results against earlier runs without a human.
- A dictation, a reading with pause and resume, and a stop during final revision run
  against the signed debug app in background mode, with no human, no focus change and
  no sound, and assert on their results. A foreground dictation into a field passes
  when the Mac is free.
- Release builds contain no driver, file audio or event log code.
- Remaining human checks run as guided sessions that produce evidence files.
- `AGENTS.md` carries the agent rule, and the 0007 items have scenarios or a recorded
  reason they need a human.

## Verified on 2026-10-03

On the development Mac (M1 Pro, macOS 27.2, Xcode 27.0, Swift 6.4):

- **MLX links with `swift build`.** It needs Xcode's Metal Toolchain component, installed
  with `xcodebuild -downloadComponent MetalToolchain`, so the bench and app can share one
  build. Details are in the [local models research](../spikes/local-models/research.md#downloads-licensing-and-packaging).
- **Apple services run from the command line.** Transcription, voice and cleanup all ran
  without permission prompts.
- **Distributed notifications cross processes.** They were delivered between two
  separate unsigned command-line processes.
- **Focus can't be taken while another app is in use.** A terminal-launched window
  became key only while the terminal's app was frontmost. Hence the two scenario modes.
- **Snapshots render state, not glass.** `ImageRenderer` drew layout, text and colour
  without the glass effect; `cacheDisplay` drew nothing.

## Open questions

- Whether foreground scenarios could run unattended in a macOS virtual machine, with
  permissions granted once. Not needed until background mode leaves real gaps.
- Whether file audio should later be complemented by a virtual input device, such as
  BlackHole, to cover real capture. Not needed until a capture regression shows the gap.
- Whether the debug app can capture its own windows for faithful snapshots after a
  one-time Screen Recording grant.
