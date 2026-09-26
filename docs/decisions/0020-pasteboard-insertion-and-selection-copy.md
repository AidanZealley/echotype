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
