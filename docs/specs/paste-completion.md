# Observe paste completion

Status: draft for approval, 2026-10-03. Implementation is not authorised by this document alone.

## Goal

End the pill's "Inserting" phase as soon as the destination field shows the dictated
text at the paste position. When the field cannot show it, finish after a shorter
fixed fallback. Keep Cmd+V as the insertion mechanism.

Confirmation is a simple, cheap check that covers common text fields. Its cost depends
on the transcript's length, not the document's. It is not proof of delivery, and edge
cases that the check misses use the fallback.

## Current behaviour

[`Clipboard.insert`](../../Sources/EchoTypeApp/Clipboard.swift) posts Cmd+V, waits
800 ms, then conditionally restores the previous clipboard. Reply requests post
Return after 200 ms and wait another 600 ms. Neither delay confirms receipt.
The pill remains visible until the clipboard transaction returns.

[`DestinationFocus`](../../Sources/EchoTypeApp/Destination.swift) already retains
the destination's field and reads attributes with a bounded messaging timeout,
including Electron's `AXManualAccessibility` workaround. Reuse both.

## Proposed behaviour

1. After the existing cancellation and destination checks pass, read the captured
   field's selected range (`kAXSelectedTextRangeAttribute`) and keep its location as
   the paste anchor. Paste replaces any selection, so its start is the anchor either
   way. An unreadable range means no evidence is available.
2. Write the transcript once and post Cmd+V once, as today.
3. If an anchor was read, poll the field every 25 ms for up to 400 ms. Let `n` be the
   transcript's UTF-16 length, because Accessibility ranges use UTF-16 offsets. Confirm
   when the selected range is `(anchor + n, 0)` and the string for range `(anchor, n)`
   (`kAXStringForRangeParameterizedAttribute`) equals the transcript. Stop polling
   after the first failed read. The deadline counts poll iterations, matching
   `copySelection`.
4. Without confirmation, finish when the 400 ms fallback ends.
5. For reply requests, revalidate the destination after confirmation or fallback and
   immediately before posting Return. Suppress Return when the destination changed or
   is unavailable. Remove the separate 200 ms send delay and the 600 ms wait after
   Return. This feature confirms insertion only, not submission.
6. Restore the saved clipboard under the existing snapshot-validity and ownership
   rules, and return. The pill ends through the existing operation completion path.

The anchored check treats appending, caret insertion and selection replacement as
one rule, and handles non-ASCII text through UTF-16 lengths. Pasting over an identical
selection confirms, because the caret moves to the end of the pasted text. Copies of
the transcript elsewhere in the field cannot confirm. Fields without a readable
selected range or string-for-range support, apps that transform pasted text, and
terminals use the fallback.

The 400 ms fallback is an initial product choice that halves the existing wait.
Each read is bounded by the existing 100 ms messaging timeout, so a slow but
successful read can stretch the window slightly. If compatibility results show that
400 ms is too short, report the evidence and propose a revised duration instead of
adding per-app delays.

## Integration boundary

Add two bounded accessors to `Destination`: the selected range, and the string for a
range. Inject them into `Clipboard.insert` alongside `verify`, using the existing
`access.wait` for timing. Expected touches are `Clipboard.swift`, `Destination.swift`
and focused tests. Do not add AX observers, notification subscriptions, a separate
helper type, a whole-value fallback check, app-specific adapters or settings.

Keep `InsertionResult` and the single controller caller unchanged. Trace results
continue to describe attempted insertion and sending, including fallback, rather than
claiming confirmed delivery. Clipboard transaction serialisation and post-write
cancellation behaviour stay as they are.

## Acceptance criteria

- A native or Electron field that exposes its selected range and string for range
  ends "Inserting" when the transcript is observed at the anchor, without waiting out
  the fallback.
- Appending, caret insertion, selection replacement and non-ASCII transcripts confirm.
- Copies of the transcript elsewhere in the field, or a caret at any other position,
  do not confirm Paste.
- Unsupported attributes, failed reads and terminals finish through the 400 ms fallback.
- Reply requests post Return at most once, after confirmation or fallback and a fresh
  destination check. They never repeat Paste or send into a newly focused field.
- Clipboard restoration behaves as it does today.
- No new permissions, settings, trace schema or changes to selection Copy are needed.

## Verification and scope

Add focused tests using the scripted `wait` and injected range and string readers:
confirms at the anchor including a non-ASCII transcript, does not confirm when the
caret or text is elsewhere, falls back when the range is unreadable, and posts Return
only after confirmation or fallback. Retain the existing clipboard ownership and
cancellation tests. Run the app test suite and build checks.

Verify a signed development build with TextEdit, Visual Studio Code and T3 Code,
including caret insertion and selection replacement. Electron support for these
attributes is less proven than for the plain value, so record whether each target
confirms or falls back. Check a terminal to exercise the fallback. Record completion
latency.

Update [decision 0020](../decisions/0020-pasteboard-insertion-and-selection-copy.md)
to describe the confirmation and fallback rules once this spec is implemented.

Estimated size is 70–100 implementation lines plus focused tests. Confirming Return
delivery and per-app compatibility work are outside this scope.
