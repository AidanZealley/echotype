# Observe paste completion

Status: draft for approval, 2026-10-03. Implementation is not authorised by this document alone.

## Goal

End the pill's "Inserting" phase as soon as Accessibility confirms that the dictated
text appeared in the original destination. Use a short, bounded fallback when the
destination cannot provide that evidence. Keep Cmd+V as the insertion mechanism.

## Current behaviour

[`Clipboard.insert`](../../Sources/EchoTypeApp/Clipboard.swift) posts Cmd+V, waits
800 ms, then conditionally restores the previous clipboard. Reply requests post
Return after 200 ms and wait another 600 ms. Neither delay confirms receipt.
The pill remains visible until the clipboard transaction returns.

[`DestinationFocus`](../../Sources/EchoTypeApp/Destination.swift) already retains
the destination's application, window, field and PID. It requests
`AXManualAccessibility` where offered to expose Electron's Accessibility tree.
Reuse that captured target and compatibility behaviour.

## Proposed behaviour

1. After queued clipboard cleanup, prepare observation of the captured destination
   before writing the transcript or posting Paste. Read the field's current text
   and selected range where supported. Subscribe to value changes before Paste so
   a fast insertion cannot be missed.
2. Preserve the existing cancellation and destination checks at the write boundary.
   Preparation must not grant permission to paste into a different field. Release
   observation if insertion is skipped.
3. Write the transcript once and post Cmd+V once. Start a single 400 ms completion
   deadline from posting Paste.
4. Complete early only when a post-Paste read confirms the expected text replacement
   in the captured field. Compute the expected value from its prior text, selection
   and transcript using Accessibility-compatible text offsets. A generic value
   change, caret movement or pre-existing occurrence of the transcript is not proof.
   If replacement would leave the value unchanged, use the fallback.
5. Treat value-change notifications as prompts to re-read the field. Perform an
   immediate post-Paste read as well. If notifications are unsupported but text and
   selection are readable, use bounded polling within the same deadline. If evidence
   is unavailable, ambiguous or does not match, finish at the deadline. Errors must
   not cause an early success or an unbounded wait.
6. For reply requests, wait for confirmation or the same fallback deadline, then
   revalidate the destination immediately before posting Return. Suppress Return
   when the destination changed or is unavailable. Remove the separate 200 ms send
   delay and the 600 ms wait after Return. This feature confirms insertion only;
   it does not confirm submission.
7. Restore the saved clipboard under the existing snapshot-validity and ownership
   rules, release observation, and return. The pill ends through the existing
   operation completion path, without a separate UI timer.

The 400 ms fallback is an initial product choice, not a delivery guarantee. It halves
the existing wait for unsupported targets. Record compatibility results before
shipping; if they show that 400 ms is too short, report the evidence and propose a
revised duration instead of adding per-app delays.

## Integration boundary

Keep completion detection in one small, app-local helper used by `Clipboard.insert`.
Its responsibility is to prepare evidence for a destination and await confirmation
or expiry after Paste, with explicit cleanup. A narrow internal result can distinguish
confirmation from fallback for tests. Avoid a general Accessibility framework,
persistent observers, app-specific adapters or new settings.

Expected implementation touches are `Clipboard.swift`, `Destination.swift`, one new
helper and focused tests. Expose only the destination access the helper needs.
Keep the production `Clipboard.insert` call signature and `InsertionResult` unchanged;
the single controller caller, dictation operation and pill should need no behavioural
changes. Existing trace results continue to describe attempted insertion and sending,
including fallback, rather than claiming confirmed delivery.

Maintain clipboard transaction serialisation. Once the write occurs, cancellation
must not abandon restoration or observer cleanup. A subsequent clipboard operation
must wait for this transaction to finish. Use bounded Accessibility messaging and
account for in-flight reads when enforcing the deadline; do not add a fresh timeout
after each notification or polling attempt.

## Acceptance criteria

- A supported native or Electron field ends "Inserting" when the expected replacement
  is observed, without waiting out the fallback. App scheduling and the existing
  panel fade may add visible latency.
- Appending, inserting at a caret, replacing selected text and non-ASCII text produce
  correct expected values. Unrelated edits and unchanged values do not confirm Paste.
- Missing attributes, unsupported notifications, destroyed fields and failed reads
  finish through the bounded fallback without crashes or leaked observers.
- Reply requests post Return at most once, after confirmation or fallback and a fresh
  destination check. They never repeat Paste or send into a newly focused field.
- Clipboard restoration preserves all saved types, respects external writers, and
  leaves the transcript when the original clipboard was empty, as it does today.
- Every exit releases observer registrations, run-loop sources and polling work.
- No new permissions, settings, trace schema or changes to selection Copy are needed.

## Verification and scope

Add focused tests for evidence matching, early completion, fallback, observer cleanup,
and Return ordering. Retain the existing clipboard ownership and cancellation tests.
Inject the observation boundary and timing needed to test these behaviours without
real sleeps or live Accessibility. Run the relevant app test suites and build checks.

Verify a signed development build with TextEdit, Visual Studio Code and T3 Code,
including caret insertion and selection replacement. Check a terminal or another
target without sufficient text evidence to exercise fallback. Record completion
latency and clipboard restoration results. Do not claim majority coverage from the
Electron tree workaround alone; the target must also expose usable text evidence.

Update [decision 0020](../decisions/0020-pasteboard-insertion-and-selection-copy.md)
to describe the implemented confirmation and fallback rules once this spec is approved
and implemented. Leave the accepted decision unchanged during spec review.

Estimated size is 200–350 implementation lines plus focused tests. The integration
is contained; cross-app evidence quality and observer lifetime are the main sources
of complexity. Per-app compatibility adapters and confirmation of Return delivery
are outside this scope.
