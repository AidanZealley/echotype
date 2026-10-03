# 0020 Own clipboard transactions and verify the destination before paste

Status: accepted, 2026-09-26. Updated for shared clipboard ownership on 2026-09-30,
Electron compatibility on 2026-10-01 and paste confirmation on 2026-10-03.

## Context

EchoType inserts into native editors, terminals and Electron apps. Setting an
Accessibility element's value is unreliable across those targets, so insertion uses
Cmd+V. A transcription can finish after the user changes fields. Reading selections
also uses the clipboard and must not race insertion or its restoration.

## Decision

- One main-actor `Clipboard` service serialises selection Copy, insertion, restoration
  and explicit Last Dictation Copy. Later transactions wait for pending cleanup.
- Capture the destination when dictation enters finishing. `DestinationFocus` retains
  the application, window and editing-target Accessibility objects and PID. Bounded
  queries and two matching samples establish identity, including changes between fields
  in the same window. Advisory readiness checks never supply the insertion token.
- Electron can hide its web Accessibility tree until an assistive client requests it.
  When the application exposes `AXManualAccessibility` as false, request true before
  looking up focus. T3 Code demonstrated this requirement. Keep the same role, enabled,
  window, PID and two-sample identity checks after requesting support.
- Save all pasteboard item types, then recheck cancellation and destination immediately
  before writing. Destination loss skips paste and preserves final text in Last
  Dictation. Do not activate another app or restore focus automatically.
- Write the final transcript once and post Cmd+V with explicit Command flags. Once the
  write-and-paste transaction starts, the clipboard service owns completion.
- Just before writing, read the field's selected range and keep its location as the
  anchor. After Cmd+V, poll every 25 ms for up to 400 ms. Paste is confirmed when the
  selected range is a caret at the anchor plus the transcript's UTF-16 length and the
  string for the transcript's range at the anchor equals the transcript. The string is
  read only after the caret moves. Polling stops at the first failed read. An unreadable anchor, unsupported attributes, transformed
  text and terminals finish after the full 400 ms fallback instead. Reads use the same
  100 ms messaging timeout. No observers or whole-value comparison are used.
- Then restore saved contents if their snapshot was valid and EchoType still owns the
  write. Leave the transcript when the original clipboard was empty.
- An eligible reply request posts Return with empty flags after confirmation or
  fallback, only if the destination still matches. A failed second check suppresses
  Return without repeating paste. Synthetic keys establish an attempt, not editor
  receipt, and confirmation covers insertion only, not submission.
- Selection Copy posts Cmd+C and keeps its full 300 ms response window, even after
  cancellation. Read a string and restore only while ownership remains valid. Apps
  that copy a current line without a selection retain those semantics.

## Consequences

Clipboard change counts reveal writes, not their authors. An external write observed
first can be mistaken for a Copy response. A second write prevents restoration, and a
Copy response later than 300 ms can still overwrite a later operation. A change during
snapshot saving or destination verification invalidates that snapshot; a change after
EchoType's write prevents restoration.

Focus checks and paste cannot be atomic across processes. Strict identity verification
reduces accidental insertion and sending, but does not prove delivery. Recovery stays
an explicit user action in Last Dictation, as [0023](0023-last-dictation-window.md)
describes.

Signed checks covered TextEdit Copy/paste/Return, typed clipboard restoration,
destination loss and recovery. Same-window field checks passed in TextEdit, Ghostty
and Visual Studio Code. T3 input detection and dictation passed after the Electron
correction. Terminal.app remains unverified.
