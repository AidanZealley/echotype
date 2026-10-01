# SessionMachine redesign whole-feature review

Status: not started. Begin only after workstreams 1 and 2 are Accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in the plan and the [approved specification](../session-machine-redesign.md). Read the accepted handoffs, but review the combined diff and surrounding code independently.

Audit:

- Every specification acceptance criterion and "Behavior to preserve" item: name the test that covers each one.
- Finishing lifecycle and cancellation across `SessionMachine`, `STTClient`, `DictationOperation` and `DictationController`.
- Dependency direction: the session makes no calls up into the operation.
- Duplicated state, unowned tasks, stale fakes or helpers left from the old callbacks, and speculative machinery.
- Test value: tests assert outcomes rather than internal ordering.
- Agreement of decision 0024 and code comments with the implementation.

Record findings as Required, Optional or Question, with evidence.

### Whole-feature verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage
swift build -c release --product EchoTypeApp
grep -rnE 'onFinishing|onAbort|finishingEffect|abortTask|finishingTask|closingSend' Sources Tests
git diff --check
```

The `grep` must print nothing. No live xAI calls, installation or publication.

## Initial whole-feature review

- Reviewer: `TBD`
- Branch, base and reviewed head: `TBD`
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
