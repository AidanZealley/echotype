# Workstream 3: Live protocol validation

Status: not started.

## Task packet

### Outcome

A recorded, evidence-backed account of how the xAI streaming endpoint actually
behaves, and one integration test that reproduces it. The specification's pause
behaviour was written from documentation; this workstream replaces that assumption
with observation.

### Scope

- One integration test that connects to `wss://api.x.ai/v1/stt` using the transport
  from workstream 2, streams a fixture WAV as 16 kHz PCM through the converter from
  workstream 1, and records the full event sequence.
- The test is skipped unless `XAI_API_KEY` is present in the environment, so the normal
  test run is unaffected and no secret is ever committed.
- A written record, in this document, answering these questions:
  - When does `transcript.partial` arrive, and how often?
  - What exactly distinguishes `is_final` from `speech_final`?
  - Does a `speech_final` reliably follow roughly `endpointing` milliseconds of
    silence, and does the specification's `endpointing=2000` behave as expected across
    a deliberate pause?
  - What does `transcript.done` return after `finalize` then `audio.done`, and does it
    repeat text already delivered or only the remainder?
  - Does anything arrive that the specification does not describe?
- Any contradiction with the specification recorded as drift, with enough evidence for
  Aidan to decide whether to change the specification or the implementation.

### Non-goals

- Building the session machine. That is workstream 4, which consumes these findings.
- Load testing, latency benchmarking or cost measurement.
- Testing the batch endpoint.
- Making the integration test part of the default suite. It costs money and needs a
  network.
- Fixing a specification defect this workstream discovers. Record it; the owning
  workstream or Aidan decides.

### Initial ownership

Creates and owns `Tests/EchoTypeCoreTests/Integration/` and a fixtures directory.

Does not change production code, except to fix a defect the live protocol exposes in
workstream 2's types, which must be recorded as drift and named in the handoff.

### Required seams

Consumes workstream 2's event types, `WebSocketTransport` and its live implementation,
and workstream 1's `AudioConverter`. Produces findings that workstream 4 depends on.

### Acceptance criteria

1. The integration test runs against the live service and passes, or the workstream is
   closed as not run following Aidan's decision at gate G1.
2. `swift test --disable-xctest` still exits 0 with `XAI_API_KEY` unset, with the
   integration test skipped rather than failed.
3. No API key, recording or transcript appears in any committed file.
4. Every question in the Scope section is answered in the Findings section below, from
   observed evidence rather than from the documentation.
5. Any contradiction with the specification is recorded as drift.

### Targeted verification

```bash
swift test --disable-xctest
XAI_API_KEY=<supplied by Aidan> swift test --disable-xctest
```

## External validation

- Gate and placement: G1, before the implementation can be verified.
- Status: `Pending`
- Candidate and instructions: see the External validation gates section of
  [plan.md](plan.md). Aidan supplies `XAI_API_KEY` in the environment and a 15 to 30
  second WAV of himself speaking containing at least two pauses of three seconds or
  more.
- Required evidence: the full recorded event sequence from one live session.
- Attempts and lasting decisions: `TBD`
- Resume condition: the sequence is recorded and contradictions are noted.

A connection or encoding failure the lead can diagnose from the response is a
troubleshooting loop inside this workstream, not a new review cycle. A missing key or
recording is an escalation.

## Findings

- Partial cadence: `TBD`
- `is_final` versus `speech_final`: `TBD`
- Endpointing behaviour across a deliberate pause: `TBD`
- What `transcript.done` returns: `TBD`
- Undocumented behaviour: `TBD`
- Contradictions with the specification: `TBD`

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
