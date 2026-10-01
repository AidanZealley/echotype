# Workstream 2: Invert finishing ownership

Status: not started.

## Task packet

### Outcome

The specification's Design is implemented. `SessionMachine` never calls into its owner. `DictationOperation` sequences finishing in one `finish()` routine. One `reschedule()` computes the next deadline from state, and `transcript.done` uses the `closingStarted` rule. Behavior is unchanged, as shown by workstream 1's tests passing without weakened assertions and by a signed smoke check.

### Scope

- `SessionMachine`:
  - Remove `onFinishing`, `onAbort`, `finishingEffect`, `abortTask`, `finishingTask` and `closingSend`.
  - Expose `run()`, `send(audio:)`, `beginFinishing()`, `sendClosing()`, `cancel()`, `fail(_:)` and `snapshots`, as the specification defines them.
  - On the hard cap, call `beginFinishing()` internally and publish the `finalizing` snapshot.
  - Replace the scattered `clock.schedule` calls with one `reschedule()` covering readiness, silence and hard cap, paused hard cap, and the finishing deadline.
  - Apply the `closingStarted` rule for `transcript.done`.
  - Remove `hasRun` and the early-ending path in `run()` if they are no longer needed. Keep them only if a listed behavior requires them, and say why in the handoff.
- `STTClient`: adjust only what `sendClosing()` needs, such as waiting for readiness when audio is held.
- `DictationOperation`:
  - Add one `finish()` routine, started at most once from the stop hotkey, reply-request detection, or a `finalizing` snapshot it didn't request. It runs the specification's four steps in order.
  - After `session.run()` returns, stop capture, cancel the pump and the finish routine, then join both.
  - Remove `enterFinishing` and `abortCapture`, now that the session no longer calls them.
- Update `SessionMachineTests` and `STTClientTests` for the new API. Keep tests of protocol and transcript behavior, and delete tests that only pin removed task ordering.
- Update decision 0024 to describe finishing ownership after this change.
- Run gate G1.

### Non-goals

- Clipboard, destination, reading, MCP, `TranscriptAssembler`, `Reviser`, settings or presentation changes.
- Changing `SessionClock` beyond what one `reschedule()` needs.
- New configuration, retries, logging or observation hooks.

### Initial ownership

- `Sources/EchoTypeCore/SessionMachine.swift`
- `Sources/EchoTypeCore/STT/STTClient.swift`
- `Sources/EchoTypeApp/DictationOperation.swift`
- `Tests/EchoTypeCoreTests/SessionMachineTests.swift`
- `Tests/EchoTypeCoreTests/STTClientTests.swift`
- `Tests/EchoTypeCoreTests/Support/` only if a fake needs the new API
- `docs/decisions/0024-dictation-operation-lifetime.md`
- Exception: `Tests/EchoTypeAppTests/DictationOperationTests.swift` may change only to follow a renamed or removed API, under the plan's contract. Each such edit is listed in the handoff.

### Required seams

- `DictationOperation.Dependencies`, `Result` and `Presentation` stay unchanged. See the plan's cross-workstream contracts.
- `DictationController` and `SpeechAdmissionTests` need no changes. If either does, record it as drift.

### Acceptance criteria

- None of `onFinishing`, `onAbort`, `finishingEffect`, `abortTask`, `finishingTask` or `closingSend` remains (`grep` finds none in `Sources` or `Tests`). `conclude` joins nothing owned by the operation.
- Deadlines are scheduled only from `reschedule()`.
- Workstream 1's `DictationOperationTests` pass with no assertion removed or weakened.
- Every "Behavior to preserve" item is covered by a passing test in either the operation or core suites.
- The full suite and release build pass. `DictationOperationTests` and `SessionMachineTests` pass 20 consecutive runs.
- Decision 0024 matches the code.
- G1 Passed.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachineTests|STTClientTests|DictationOperationTests|SpeechAdmissionTests|CoordinatorTests'
for i in $(seq 20); do XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'DictationOperationTests|SessionMachineTests' > /dev/null || echo "failed run $i"; done
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
swift build -c release --product EchoTypeApp
grep -rnE 'onFinishing|onAbort|finishingEffect|abortTask|finishingTask|closingSend' Sources Tests
git diff --check
```

The `grep` must print nothing.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
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

## External validation

- Gate and placement: G1, after closure before acceptance
- Status: Pending
- Candidate and instructions: Build with `./scripts/build-app.sh release .build/EchoType-redesign.app` and record the executable SHA-256. Instructions for Aidan: quit the running EchoType, run `open .build/EchoType-redesign.app`, then in TextEdit or any text field:
  1. Dictate a sentence and stop. It pastes once.
  2. Stop while still speaking the last words. No final words are lost.
  3. Press Escape while Transcribing. Nothing is inserted.
  4. Dictate ending with "reply with EchoType". It pastes and sends Return.

  Afterwards, quit the candidate and relaunch your usual EchoType.
- Required evidence: Aidan's pass or fail for each of the four checks, recorded in the escalation entry.
- Attempts and lasting decisions: `TBD`
- Resume condition: all four pass, or Aidan records an explicit scope decision.
