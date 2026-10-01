# Workstream 1: Protect finishing with outcome tests

Status: not started.

## Task packet

### Outcome

`DictationOperationTests` cover every behavior the redesign must preserve by asserting observable outcomes against today's code: inserted text, frame order on the fake transport, trace contents, presentation reached, and which resources were released. The harness is clearly smaller than today's. No production code changes.

### Scope

- Rewrite the `Harness` in `Tests/EchoTypeAppTests/DictationOperationTests.swift` around three controllable fakes: a transport that records frames and lets the test emit events, a manual clock, and a capture stream the test feeds and finishes. Add a gate only where a test must hold a specific suspension (a stalled binary send, closing send or capture drain, a suspended final revision, or a suspended insertion).
- Write one test per item in the specification's "Behavior to preserve" list that `DictationOperation` can observe. Parameterise only where cases share every step but one input.
- Keep existing operation tests that still assert outcomes, adapted to the new harness. Delete tests that pin internal task ordering or presentation call counts without protecting a listed behavior.
- Keep the readiness tests (Select an input) and Test-mode test, since they protect accepted behavior.

Suggested, not required: express timing as "advance the clock by N" and "finish the capture stream" rather than as sequences of gate openings.

### Non-goals

- Changing any file under `Sources/`.
- Testing `SessionMachine` or `STTClient` directly. Those tests belong to workstream 2.
- Coverage targets, permutation matrices or retry paths beyond the listed behavior.

### Initial ownership

- `Tests/EchoTypeAppTests/DictationOperationTests.swift` only.

### Required seams

- Drive `DictationOperation` only through `Dependencies`, `run()`, `commit()`, `cancel()`, `captureFailed(_:)`, `microphoneReady()` and its published presentation. Do not reference `SessionMachine` internals, `onFinishing`, `onAbort` or `enterFinishing`. Workstream 2 must be able to rewrite those without touching this file.

### Acceptance criteria

- Each "Behavior to preserve" item observable at the operation level has a named test asserting its outcome. The handoff lists the mapping from item to test.
- No test asserts internal call order, task identity, or a presentation count, except where the order is the behavior (closing frames after the last audio chunk).
- The harness has fewer gates and counters than today's 11 gates and about 20 counters.
- `DictationOperationTests` pass 20 consecutive runs, with no flaky timing.
- The full deterministic suite passes.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter DictationOperationTests
for i in $(seq 20); do XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter DictationOperationTests > /dev/null || echo "failed run $i"; done
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
git diff --check
```

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Behavior-to-test mapping: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`
