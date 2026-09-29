# Last Dictation window

A window that shows what happened during the last dictation: where the stream committed
text, which revision requests ran, what each one returned, and which words the inserted
text lost or re-punctuated compared with what was streamed.

Status: approved, 2026-09-29. Revised the same day to make it a normal feature with no
debug gate (see [0023](../decisions/0023-debug-window.md)). Implemented.

## Problem

Cleanup is inconsistent and nothing shows why. `Reviser` drops failed, timed-out and
rejected requests silently (see [0021](../decisions/0021-revise-committed-dictation.md)),
so a dictation that came out fragmented looks the same whether no revision ran, every
revision was rejected, or the model returned the text unchanged. The only way to tell
today is to reproduce the requests by hand.

## Behaviour

- Every launch records the last dictation, in the installed app and the development
  build alike. There is no setting and no launch flag. A menu bar item, **Last
  Dictation…**, below **Settings…**, opens the window. `--hud-demo` records no dictation
  and has no item.
- The window opens only from the menu item. The app launches as an accessory app with no
  window open, and a window left open at quit does not come back at the next launch.
- The window shows the most recent dictation that reached `running`, whatever its
  outcome: inserted, failed, cancelled or empty. The Test button is not recorded.
  Cancellation does not wait for an in-flight revision merely to complete the trace.
- While the window is open, it updates when a dictation ends. It never orders itself
  front or takes focus, so a dictation that finishes with the window open still inserts
  into the target app. Before the first dictation it says "No dictation yet".
- It opens the same way as Settings: the app becomes a regular app while it is open and
  returns to an accessory app when the last of its windows closes. Closing the Last
  Dictation window while Settings is open must not hide the Dock icon, and the reverse.
- The trace stays in memory. It is not written to disk, logged or sent anywhere. Only
  Copy as JSON moves it, to the pasteboard.

### Layout

From top to bottom:

1. **Summary line.** Duration, word count, commit count, and request counts by outcome,
   for example `42s · 138 words · 9 commits · 11 requests: 7 accepted, 2 rejected,
   1 failed, 1 cancelled`. When cleanup was off, `cleanup off` replaces the request
   counts. The session outcome follows when it was not an insert, for example
   `failed: Connection failed: …`.
2. **Text.** The streamed committed text, word by word, marked against the inserted text:
   - Deleted words: struck through, in red.
   - Words whose punctuation or case changed: the inserted form, in amber. The streamed
     form shows on hover.
   - Commit boundaries: a thin vertical mark between words, with the seconds since the
     previous commit on hover. Boundaries show where pauses split the stream.
   - Everything else in the primary text colour.
3. **Requests.** One row per recorded revision request, oldest first: time since the session
   started, `live` or `final`, window word count, latency, and the outcome. A rejected
   row names the first word that failed the check, for example
   `rejected at "i'm"`. Each row expands to show the window sent and the reply.
4. **Copy as JSON** button, which puts the whole trace on the pasteboard, so a bad
   session can be pasted into a conversation with an agent.

Use the app's system colours so both themes work. Keep the text selectable.

## Implementation

### Core

- **`DictationTrace`**, a `Codable`, `Equatable`, `Sendable` value in a new
  `Sources/EchoTypeCore/DictationTrace.swift`:

  ```swift
  public struct DictationTrace: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var endedAt: Date?
    public var cleanUp: Bool
    public var commits: [Commit]          // each growth of committed text, in order
    public var revisions: [Revision]      // from Reviser, in order
    public var streamed: String           // the final committed text before revision
    public var inserted: String           // what went in, or "" when nothing did
    public var outcome: Outcome

    public struct Commit: Codable, Equatable, Sendable {
      public var at: Date
      public var text: String
    }

    public struct Revision: Codable, Equatable, Sendable {
      public var at: Date
      public var isFinal: Bool
      public var window: String
      public var reply: String?           // nil when the request threw
      public var duration: TimeInterval
      public var result: Result
    }

    public enum Result: Codable, Equatable, Sendable {
      case accepted
      case unchanged                      // accepted, but identical to the window
      case rejected(word: String)
      case replyRequestRemoved           // the reply dropped a spoken EchoType reply request
      case empty
      case failed(String)                 // the thrown error, described
      case cancelled                      // cancelled at stop
      case superseded                     // stale final reply, see Reviser.revise
    }

    public enum Outcome: Codable, Equatable, Sendable {
      case inserted, nothing, cancelled
      case failed(String)
    }
  }
  ```

  Adjust names as the code suggests, but keep one type that the window renders and the
  JSON button encodes.

- **Marking.** `DictationTrace.marks` returns the streamed words, each marked `kept`,
  `deleted` or `changed(inserted: String)`, with the index of the commit that starts at
  it, if any.
  Align the words as `Reviser.isFaithful` does: split both texts into words, normalise
  them the same way, and walk the streamed words forward, matching each inserted word to
  the next equal one. Unmatched streamed words are deleted. A matched word whose raw form
  differs is changed. Every revision is a subsequence of its window, so the inserted text
  is a subsequence of the streamed text and the walk always finishes. Commit boundaries
  come from the commit texts' word counts.

  When a word repeats, the walk can mark a different copy as deleted than the model
  removed. The text reads the same, so this is acceptable.

- **`Reviser`** records every request it makes and exposes them as
  `public private(set) var attempts: [DictationTrace.Revision]`. Time each request with
  `ContinuousClock`. The existing guards map to results:
  - `Task.isCancelled` after the request: `cancelled`.
  - `finishing && input != committed`: `superseded`.
  - The request threw: `failed`, with `String(describing: error)`.
  - Empty after trimming: `empty`.
  - Unfaithful: `rejected(word:)`.
  - Faithful but dropping a spoken EchoType reply request: `replyRequestRemoved`,
    preserving the existing guard from [0022](../decisions/0022-voice-replies.md).
  - Faithful and equal to the window: `unchanged`. Otherwise `accepted`.

  Split `isFaithful` into `firstUnmatchedWord(in revision: String, from input: String)
  -> String?` and keep `isFaithful` as `firstUnmatchedWord(...) == nil`, so the prompt
  tests keep their call. The word normalisation stays in one place.

### App

- **`DictationController`** gains `private(set) var lastTrace: DictationTrace?`,
  observable. It is nil until the first dictation ends.
  - `dictate` starts a trace when the session starts running, with `cleanUp` from the
    session's settings.
  - `run` appends a `Commit` whenever `snapshot.committed` grows, with the new suffix,
    trimmed, as its text. `committed` only grows at its end
    ([0003](../decisions/0003-transcript-assembly.md)), so the suffix is exactly the new
    segment.
  - After `revisedOutcome`, it fills `streamed`, `inserted`, `outcome` and `endedAt`,
    copies `reviser.attempts` into `revisions`, and publishes the trace as `lastTrace`.
    `Outcome.nothing` covers both a cancelled and an empty session, so the trace records
    `cancelled` when the last snapshot's state was `.cancelled` and `nothing` otherwise.
  - `test()` records nothing.
- **`LastDictationWindow`**, in `Sources/EchoTypeApp/Views/LastDictationWindow.swift`,
  renders `controller.lastTrace` as described above. The text is a non-editable,
  selectable `NSTextView` built from one attributed string, so it wraps and selects as a
  paragraph and shows hover text for single words (see 0023).
- **`EchoTypeApp`** adds a `Window("Last Dictation", id: "last-dictation")` scene with
  `.defaultLaunchBehavior(.suppressed)`, `.restorationBehavior(.disabled)` and
  `.commandsRemoved()`. It shows the menu item whenever it has a controller, which
  `--hud-demo` does not. The item opens the window with `openWindow` through
  `presentWindow`, the activation helper Settings also uses. Each scene's `onDisappear`
  switches back to `.accessory` only when no other window that can become main is still
  visible or minimised.

### Docs

The README lists Last Dictation among its features.

### Decision record

`docs/decisions/0023-debug-window.md` records the trace, the marking rule, the window's
activation and the removal of the original debug gate. `docs/decisions/README.md` links
it.

## Tests

- `DictationTrace.marks`: streamed `"I-I'm never sure. Why it fails"` in two commits
  and inserted `"I'm never sure why it fails"` gives `I` deleted, `I'm` kept,
  `sure.` changed to `sure`, `Why` changed to `why`, and a boundary before `Why`.
- `Reviser.attempts`: with replies that are accepted, unfaithful, and thrown, the
  attempts record `accepted`, `rejected(word:)` naming the added word, and `failed`, in
  order. This pins the mapping the window depends
  on. The other results need no tests.

## Open questions

- **History.** One session is enough while the window is open, because it updates as
  each dictation ends. If sessions are regularly lost by dictating again before looking,
  keep the last three and add a picker.
- **Pause lengths.** Time between commits includes the time spent speaking, so it is only
  a rough stand-in for pause length. If endpointing is the suspect, record the gap
  between the last partial of one utterance and its `speech_final` instead.

## Final gate

After implementation, run `swift test`, then check on the Mac with the development
build:

- `./scripts/run.sh` starts the app with no window open. **Last Dictation…** sits below
  **Settings…** and opens the window, showing "No dictation yet".
  `./scripts/run.sh --hud-demo` shows no **Last Dictation…** item.

- Dictate a passage of more than 50 words with a pause mid-sentence, a stutter and a
  self-correction ("at three, no, four"). The window shows commit marks at the pauses,
  the stutter and the abandoned wording struck through, and the joined sentence's
  punctuation in amber. The request list accounts for every request.
- With the window open and a text editor focused, dictate again. The window updates,
  stays behind the editor, and the text goes into the editor.
- Cancel a dictation with Escape. The window shows it as cancelled.
- Copy as JSON, paste into a text editor, and check it is readable.
- Open Settings and the Last Dictation window together, close one, and check the other still
  shows and the Dock icon stays until both are closed.
- Check both themes.
