# SessionMachine redesign implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Target branch: `refactor/macos-lifecycle`, which merges to `main` as one complete rewrite after this workflow
- Integration branch: `TBD` (the target itself, or a working branch from it)
- Starting commit: `TBD`
- Review command: `lead subagents`
- Specification approved at commit: `TBD`
- Started: `TBD`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Protect finishing with outcome tests](01-outcome-tests.md) | Approved spec | Not started |
| 2 | [Invert finishing ownership](02-finishing-ownership.md) | 1 | Not started |
| Final | [Whole-feature review](final-review.md) | 1 and 2 | Not started |

Statuses: Not started, Implementing, Review, Remediation, Closure review, Blocked, Accepted. The lead updates its own row on each transition. Only one row is active at a time.

## Why these boundaries

Today's `DictationOperationTests` pin internal interleavings, so they would break under any restructuring and can't tell a regression from a reordering. Workstream 1 rewrites them around observable outcomes against the current code, without changing production code. That is a shippable improvement on its own, and it gives workstream 2 a safety net that must pass unchanged.

Workstream 2 is the single production change: removing the callbacks, the one deadline function and the `closingStarted` rule all edit the same `SessionMachine` finishing path, and splitting them would mean adapting code that the next step rewrites. It also updates the core session and client tests that call the removed API.

## Cross-workstream contracts

- Workstream 1's operation tests drive `DictationOperation` only through its `Dependencies`, `run()`, `commit()`, `cancel()`, `captureFailed(_:)`, `microphoneReady()` and published presentation. They do not reference `SessionMachine` internals, `onFinishing`, `onAbort` or `enterFinishing`.
- Workstream 2 keeps `DictationOperation.Dependencies`, `Result` and `Presentation` unchanged, so workstream 1's tests compile and pass without edits. A needed change to them is drift: record it, and change the tests only to follow the renamed API, never to weaken an assertion.
- Behavior is exactly the specification's "Behavior to preserve" list. No user-visible change.

## Ownership handoffs

- `Tests/EchoTypeAppTests/DictationOperationTests.swift`: owned by 1, then read-only for 2 except as the contract above allows.
- `Sources/EchoTypeCore/SessionMachine.swift`, `Sources/EchoTypeCore/STT/STTClient.swift`, `Sources/EchoTypeApp/DictationOperation.swift`, `Tests/EchoTypeCoreTests/SessionMachineTests.swift` and `Tests/EchoTypeCoreTests/STTClientTests.swift`: owned by 2.
- `docs/decisions/0024-dictation-operation-lifetime.md`: updated by 2 to describe the new finishing ownership.
- Final owns whole-feature corrections and `final-review.md`.

## Whole-feature acceptance

- Rows 1 and 2 Accepted, and G1 Passed.
- The full deterministic suite and the release build pass at the reviewed head.
- Every specification acceptance criterion is met or carries an approved scope decision in the log.
- CI execution stays unverified unless an Actions run exists. Agents do not publish to create one.
- When a working branch was used, it fast-forwards onto `refactor/macos-lifecycle`. The completion report tells Aidan how to bring it back with `git merge --ff-only`.

## External validation gates

| Gate | Owner and placement | Status | Candidate | Required evidence and resume condition |
|---|---|---|---|---|
| G1 Signed dictation smoke check | 2, after closure before acceptance | Pending | TBD | Aidan dictates with the signed candidate: a normal dictation, stopping mid-sentence with no lost final words, Escape while Transcribing, and one reply request that sends Return. Resume when Aidan reports results in the escalation entry |

## Escalations

None.

## Conventions learned

None yet.

## Completion summary

Filled by the final-review lead before its commit.

- Delivered outcomes: TBD
- Verification: TBD
- External validation: TBD
- Specification drift: TBD
- Deferred optional observations: TBD

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| — | None | — | — | — |
