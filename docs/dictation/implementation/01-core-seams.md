# Workstream 1: Core seams

Status: not started.

## Task packet

### Outcome

`EchoTypeApp` can import `EchoTypeCore`. A session that finalises against an endpoint
that never answers ends with a failure instead of hanging forever. A handshake rejected
with 401 arrives at the caller as `STTError.unauthorized`, proven against the live
endpoint rather than assumed.

### Scope

**The finalizing deadline.** `SessionMachine.beginFinalizing` sends `finalize` and
`audio.done` and then waits on `transcript.done` with no pending wake-up, because it
cancels the clock on the way in. If the endpoint accepts the closing messages and never
replies, `run()` never returns and the app has no way to notice.

Give `finalizing` a bounded wait on the injected clock. When it expires, conclude with
`Outcome.failed(text:error:)` carrying whatever the assembler had committed, on the same
reasoning the specification already uses for a dropped socket: a visibly truncated
transcript beats losing the speech.

The specification measured the segment boundary landing 2.73 to 2.80 seconds after the
last reported word, with the frame in hand around 3.0 seconds, from inserted digital
silence. A real room is slower. Choose a value with that margin in mind, put the reason
in a comment, and put it beside `silenceTimeout` and `hardCap` in `Settings` if it wants
tuning later.

**The 401 path.** `URLSessionWebSocketTransport.sessionError(from:)` reads
`task.response` to turn a rejected handshake into a typed `STTError`. Whether a
`URLSessionWebSocketTask` populates `response` on a rejected upgrade is an assumption
nothing has tested. Prove it with one live call carrying a deliberately wrong key. No
valid credential is needed.

If the call cannot run, because there is no network or the endpoint answers in some
third way, record what happened. A documented unknown is worth more than a green test
asserting the current behaviour of a code path nobody exercised.

**The package dependency.** Add `EchoTypeCore` to the `EchoTypeApp` target's
dependencies. One line, and it is here so that no later workstream touches
`Package.swift`.

### Non-goals

- Any transcript text, interim text or elapsed time crossing the `SessionMachine` seam.
  The overlay milestone designs that against its own requirements. Adding it now is
  guessing.
- Retrying or reconnecting a failed session.
- Changing `SessionMachine`'s existing public surface, the pause and resume rules, or the
  hard cap.
- Anything in `EchoTypeApp`.

### Initial ownership

- `Package.swift`
- `Sources/EchoTypeCore/SessionMachine.swift`
- `Sources/EchoTypeCore/STT/URLSessionWebSocketTransport.swift`
- `Sources/EchoTypeCore/Settings.swift`, only if the deadline becomes a setting
- `Tests/EchoTypeCoreTests/`

### Required seams

The deadline's expiry must be reachable in a test through the existing `SessionClock`
protocol, the way `SessionMachineTests` already drives silence and the hard cap. If it
cannot be, the design is wrong rather than the test.

Workstream 3 consumes `SessionMachine` exactly as it stands after this workstream.

### Acceptance criteria

1. A session that triggers finalisation and receives nothing further ends with
   `Outcome.failed`, carrying the text committed before the trigger, within the chosen
   deadline on the injected clock. A test pins this.
2. A session that receives `transcript.done` normally is unaffected, and the existing
   `SessionMachineTests` still pass unchanged.
3. The deadline does not fire after the session has concluded, and does not leave a task
   running past `run()` returning.
4. The live 401 result is recorded in the handoff: either `STTError.unauthorized` reached
   the caller, or what did instead.
5. `swift build` succeeds with `EchoTypeApp` depending on `EchoTypeCore`.

### Targeted verification

```bash
swift build
swift test
```

Add the focused test for criterion 1 to `Tests/EchoTypeCoreTests/SessionMachineTests.swift`.

For criterion 4, one throwaway call against `wss://api.x.ai/v1/stt` with an invalid key.
Write it as a scratch script or a test guarded off by default; do not leave a test in the
suite that needs the network to pass.

```bash
swift-format lint --recursive Sources Tests Package.swift
```

Skip the lint if swift-format is not installed and say so in the handoff.

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
