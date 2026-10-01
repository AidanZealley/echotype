# 0020 Insert through the pasteboard and copy selections after pending pastes

Status: accepted, 2026-09-26. The read-aloud copy rule was extended after the initial
implementation to cover a reading started immediately after dictation.

## Context

EchoType inserts text into terminals, Electron apps and other focused editors. Setting
an Accessibility element's value is unreliable in those targets. Streaming partials
also change, so inserting while dictating would fight the target's undo history and
autocomplete. Read aloud needs to copy the focused selection without replacing what
the user had on the clipboard.

## Decision

- Insert the final transcript once. `Inserter` saves every pasteboard item, writes the
  transcript and posts Cmd+V with explicit Command flags. After 800 ms it restores
  the saved items only if `changeCount` still identifies its write. A later insertion
  carries the original saved contents forward. A write from another app is left alone.
- Read aloud posts Cmd+C with explicit Command flags, waits up to 300 ms for the
  pasteboard to change, reads a string and restores the saved items. Apps that copy
  their current line with no selection may read that line. A stop during the copy
  still lets the bounded copy and restore finish.
- If a dictation insertion has a pending restore, the reading waits for that restore
  window to finish before posting Cmd+C. Otherwise the copy can replace the
  transcript before Cmd+V lands and prevent the user's earlier clipboard contents
  from returning. This can delay that reading by up to 800 ms; other readings start
  without the wait.

## Consequences

- The app never takes focus to insert or copy. The target editor keeps its caret.
- A paste that lands nowhere leaves the transcript on the clipboard if there were
  no earlier contents to restore. This makes the text recoverable.
- `changeCount` protects writes by other apps. The app target owns these macOS
  operations, so paste and copy behavior need checks in real target apps.

## Lifecycle rewrite update, 2026-09-30

`Clipboard` replaces `Inserter` and `Pasteboard`. Its main-actor transaction queue owns
selection Copy, insertion and restoration. A stopped selection reader lets the full
300 ms Copy window complete. Later insertion and explicit Last Dictation Copy wait for
that cleanup. Insertion preserves all saved item types and the empty-original behavior,
posts Command+V once and restores after 800 ms if it still owns the write. An eligible
Return uses empty flags after 200 ms and a fresh destination check.

`DestinationFocus` retains application, window and editing-target Accessibility objects.
It uses bounded queries and two matching samples for capture, and repeats that lookup
for verification. The session invokes its finishing callback once before explicit-stop
drain, hard-cap closing frames or failure revision. The controller captures there, not
from buffered presentation snapshots. Screen selection remains independent.

Destination loss or unavailable identity skips paste and leaves final text in Last
Dictation. Cancellation is checked immediately before the clipboard write. Once that
transaction begins, cleanup completes. A changed destination before Return suppresses
sending without repeating paste. Synthetic keys prove only an attempt, not editor receipt.

Destination identity is checked once at the write boundary, after saving the pasteboard,
and again before Return. A changed pasteboard count while saving or verifying invalidates
the saved snapshot.
A changed count after EchoType's write invalidates restoration. Copy counts
cannot identify the writer: an external write observed first can be mistaken for Copy.
A second write during the Copy window prevents restoration; a Copy response later than
300 ms can still overwrite a later operation. These public API limits remain, and the
adapter does not claim otherwise. Same-window identity checks passed in TextEdit,
Ghostty and Visual Studio Code with the approved G2 evidence in the implementation
packet. G3 signed TextEdit trials passed Copy, paste, restoration and recovery using
the production service in a controlled driver. Timing holds made focus switches
observable; they do not measure production Return timing or prove every editor accepts
a synthetic paste. Terminal.app remains unverified.
