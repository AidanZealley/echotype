# Read aloud whole-feature review

Status: not started. Begin only after every workstream is accepted.

## Reviewer task packet

Review the full branch against the starting commit in `plan.md` and the approved
[specification](../../read-aloud.md). Read the accepted handoffs in
[01-speech-core.md](01-speech-core.md) and [02-read-aloud-app.md](02-read-aloud-app.md) and
decision 0018, then review the combined diff and surrounding code independently.

Check:

- Every item in the specification's Behaviour, Implementation and Tests sections is delivered for
  the branch 0018 chose, or its drift is in the plan's decision and drift log.
- The seam between the workstreams: the PCM format and sample rate defined once in `Speech`, one
  `PCMDecoder` per reading, the auth header reused from `STTConnection`, and the cap applied
  before the request.
- Lifecycle: stopping by hotkey, Escape, click and a dictation start all cancel the fetch and stop
  the player; a reading that ends on its own fades the pill; the Keychain is read once per
  reading; the pasteboard is restored after the copy; `Inserter`'s supersede logic still holds.
- Hotkey routing: both hotkeys and Escape reach the right owner in every controller phase,
  including a test.
- Settings storage: the stored key names, independent decoding, and decision 0010.
- Machinery the specification does not ask for: retries, logging, network mocks, unused
  branches of the rejected fetch path, extra state or options.
- Test quality: the tests protect the request fields, the frames if used, split-sample decoding
  and the stored settings, not implementation details.
- Documentation agreement: decisions 0018 and 0010, the index, decision 0009 if the pill's
  behaviour changed, doc comments in the app target, and the specification's status.

Run `swift build` and `swift test`. Do not launch the app or change settings; G2 covered it.
Classify evidence as Required, Optional or Question, and name the owning file for each Required
finding.

## Initial whole-feature review

- Reviewer: `TBD`
- Branch, base, and reviewed head: `TBD`
- Verification run: `TBD`
- Acceptance-criteria audit: `TBD`
- Required findings by owner: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`
- Verdict: `TBD`

## Lead triage

- Accepted findings and owners: `TBD`
- Rejected findings and reasons: `TBD`
- Deferred optional observations: `TBD`
- Drift requiring user decision: `TBD`

## Focused closure

- Reviewed head: `TBD`
- Finding outcomes: `TBD`
- Final simplification assessment: `TBD`
- Remaining blockers: `TBD`
- Verdict: `TBD`

## Completion record

- Final verification: `TBD`
- External validation pending: `TBD`
- Specification drift: `TBD`
