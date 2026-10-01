# SessionMachine redesign implementation plan

Status: workstreams 1 and 2 accepted; final whole-feature review not started.

## Orchestration record

- Target branch: `refactor/macos-lifecycle`, which merges to `main` as one complete rewrite after this workflow
- Integration branch: `refactor/macos-lifecycle` (the target itself)
- Starting commit: `256f3bb6cb543292dee7f6e23cf0a72d73b23feb`
- Review command: `lead subagents`
- Specification approved at commit: `TBD`
- Started: `2026-10-01`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Protect finishing with outcome tests](01-outcome-tests.md) | Approved spec | Accepted |
| 2 | [Invert finishing ownership](02-finishing-ownership.md) | 1 | Accepted |
| Final | [Whole-feature review](final-review.md) | 1 and 2 | Not started |

Statuses: Not started, Implementing, Review, Remediation, Closure review, Blocked, Accepted. The lead updates its own row on each transition. Only one row is active at a time.

## Why these boundaries

Today's `DictationOperationTests` pin internal interleavings, so they would break under any restructuring and can't tell a regression from a reordering. Workstream 1 rewrites them around observable outcomes against the current code, without changing production code. That is a shippable improvement on its own, and it gives workstream 2 a safety net that must pass unchanged.

Workstream 2 is the single production change: removing the callbacks, the one deadline function and the `closingStarted` rule all edit the same `SessionMachine` finishing path, and splitting them would mean adapting code that the next step rewrites. It also updates the core session and client tests that call the removed API.

## Cross-workstream contracts

- Workstream 1's operation tests drive `DictationOperation` only through its `Dependencies`, `run()`, `commit()`, `cancel()`, `captureFailed(_:)`, `microphoneReady()` and published presentation. They do not reference `SessionMachine` internals, `onFinishing`, `onAbort` or `enterFinishing`.
- Workstream 2 keeps `DictationOperation.Dependencies`, `Result` and `Presentation` unchanged, so workstream 1's tests compile and pass without edits. A needed change to them is drift: record it, and change the tests only to follow the renamed API, never to weaken an assertion.
- Behavior is exactly the specification's "Behavior to preserve" list. No user-visible change.
- Workstream 1's tests rely on two orderings the specification already requires: the session's first clock schedule is the readiness deadline, and `beginFinishing()` arms the finishing deadline before capture stops or closing frames are sent. Breaking either is drift, not a reason to edit the tests.
- In-order delivery of audio held before the handshake is not observable at the operation level; workstream 2 keeps the `STTClientTests` that cover it.

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
| G1 Signed dictation smoke check | 2, after closure before acceptance | Passed, 2026-10-01 | `.build/EchoType-redesign.app`, executable SHA-256 `3dd36a71ba580cd3ae1d9fdfb307c13edb87fdb90f5e7c96084d549547f45415` | Aidan explicitly reported normal dictation, stop mid-sentence without lost words and Escape while Transcribing passed. His fourth test, dictated ending with "reply with EchoType", arrived as a submitted message in this thread, confirming paste and Return. See [workstream 2 external validation](02-finishing-ownership.md#external-validation) |

## Escalations

None. G1 results are preserved in the gate table and workstream 2 record.

## Conventions learned

- Outcome tests for an ordering-sensitive behavior need a mutation check: move or remove the production line the behavior depends on, confirm a test fails, then restore `Sources/` exactly. Workstream 1's first pass missed a destination captured at insertion time and a repeated stop.
- Electron focused-field lookup may require enabling its advertised AXManualAccessibility capability. Preserve two-sample capture and application/window/target/PID identity checks; readiness success alone is not insertion or signed smoke evidence.

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
| 2026-10-01 | Accept the test point rename from `closingSend` to `closingFrame` as packet-level drift | The obsolete-name check also matched the fake transport's point name. The rename changes no assertions or test behavior | Aidan | 2 |
| 2026-10-01 | Resolve optional O1 and O4 after independent review | Add a cancellation check after audio drain and before closing messages; update the SessionClock comment to include readiness and finishing. O2 remains unchanged | Aidan | 2 |
| 2026-10-01 | Add the authorised Electron destination correction to workstream 2 | T3 hid its focused web field until AXManualAccessibility was enabled. Request it only when false; retain all destination identity checks. This extends the specification and packet destination non-goal | Aidan | 2 |
| 2026-10-01 | Accept G1 on the supplied signed candidate | Aidan reported checks 1, 2 and 3 passed; his fourth dictated reply request arrived as a submitted message, confirming paste and Return. The executable hash still matches the recorded candidate | Aidan | 2 and Final |
