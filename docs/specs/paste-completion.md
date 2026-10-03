# Observe paste completion

Status: draft for approval, 2026-10-03. Implementation is not authorised by this document alone.

## Goal

End the pill's "Inserting" phase as soon as the destination field shows the dictated
text. When the field cannot show it, finish after a shorter fixed fallback. Keep Cmd+V
as the insertion mechanism.

Confirmation is a simple, cheap check that covers common text fields. It is not proof
of delivery, and edge cases that the check misses use the fallback.

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
   field's text (`kAXValueAttribute`) and count occurrences of the transcript.
   An unreadable or non-string value means no evidence is available.
2. Write the transcript once and post Cmd+V once, as today.
3. If a baseline was read, poll the field every 25 ms for up to 400 ms. Confirm when
   the transcript occurs more times than in the baseline. Stop polling after the first
   failed read. The deadline counts poll iterations, matching `copySelection`.
4. Without confirmation, finish when the 400 ms fallback ends.
5. For reply requests, revalidate the destination after confirmation or fallback and
   immediately before posting Return. Suppress Return when the destination changed or
   is unavailable. Remove the separate 200 ms send delay and the 600 ms wait after
   Return. This feature confirms insertion only, not submission.
6. Restore the saved clipboard under the existing snapshot-validity and ownership
   rules, and return. The pill ends through the existing operation completion path.

The occurrence count handles appending, caret insertion, selection replacement and
non-ASCII text without computing offsets or selection ranges. A transcript already
in the field does not confirm, because the count must increase. Pasting over an
identical selection leaves the count unchanged and uses the fallback. Apps that
transform pasted text, terminals and fields without a readable value also use the
fallback. An unrelated edit that adds the exact transcript during the window would
confirm early. That is acceptable.

The 400 ms fallback is an initial product choice that halves the existing wait.
Each read is bounded by the existing 100 ms messaging timeout, so a slow but
successful read can stretch the window slightly. If compatibility results show that
400 ms is too short, report the evidence and propose a revised duration instead of
adding per-app delays.

## Integration boundary

Add one bounded text accessor to `Destination` and inject it into `Clipboard.insert`
alongside `verify`, using the existing `access.wait` for timing. Expected touches are
`Clipboard.swift`, `Destination.swift` and focused tests. Do not add AX observers,
notification subscriptions, a separate helper type, app-specific adapters or settings.

Keep `InsertionResult` and the single controller caller unchanged. Trace results
continue to describe attempted insertion and sending, including fallback, rather than
claiming confirmed delivery. Clipboard transaction serialisation and post-write
cancellation behaviour stay as they are.

## Acceptance criteria

- A readable native or Electron field ends "Inserting" when the transcript count
  increases, without waiting out the fallback.
- A pre-existing occurrence of the transcript does not confirm Paste.
- Unreadable fields, failed reads and terminals finish through the 400 ms fallback.
- Reply requests post Return at most once, after confirmation or fallback and a fresh
  destination check. They never repeat Paste or send into a newly focused field.
- Clipboard restoration behaves as it does today.
- No new permissions, settings, trace schema or changes to selection Copy are needed.

## Verification and scope

Add focused tests using the scripted `wait` and an injected text reader: confirms on
a count increase, ignores a pre-existing occurrence, falls back when the field is
unreadable, and posts Return only after confirmation or fallback. Retain the existing
clipboard ownership and cancellation tests. Run the app test suite and build checks.

Verify a signed development build with TextEdit, Visual Studio Code and T3 Code,
including caret insertion and selection replacement. Check a terminal to exercise
the fallback. Record completion latency, and check that polling a long TextEdit
document stays responsive.

Update [decision 0020](../decisions/0020-pasteboard-insertion-and-selection-copy.md)
to describe the confirmation and fallback rules once this spec is implemented.

Estimated size is 50–80 implementation lines plus focused tests. Confirming Return
delivery and per-app compatibility work are outside this scope.
