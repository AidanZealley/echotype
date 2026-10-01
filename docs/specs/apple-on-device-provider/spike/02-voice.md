# Spike 2: Read aloud

Status: not started. Frozen task packet, subject to workflow approval.

## Task packet

### Outcome

Measured feasibility for S2 against the feature-complete Apple fallback requirement. Record answers and proposed implementation choices in the assigned specification results section, with no production implementation.

### Scope

Answer every S2 question, prioritizing Siri access through buffer synthesis. If Siri is inaccessible, test the best available installed alternatives and record their ids and quality tradeoff. Measure first-buffer latency, format/sample rate, speed mapping and range, text limit, missing-voice detection and language fallback without overwriting saved choices.

Exercise a test-only SpeechStream with a long utterance: pause pulls, record peak buffered audio and synthesis behavior, resume without loss, cancel while next() is pending, and start another reading. Verify mono Float32 conversion, constant sample rate and chunks at most 100 ms. Inspect Reader and MCP speech entry points for compatibility; actual app/MCP integration remains future verification. Record offline behavior after assets are installed. Lower voice quality is not a blocker.

### Non-goals

Production adapters, registry changes, shared contract changes, UI, deployments and production implementation packets. Do not reject solely for quality below xAI or silently omit required features. Do not promise behavior supported only by documentation or mocks.

### Initial ownership

Tests/EchoTypeCoreTests/Integration/AppleVoiceSpike.swift and test-only helpers under Integration/AppleVoice/. Own the spec section `S2 results` immediately after S2 questions. Do not change Reader, SpeechPlayer, MCP handlers or production voice lists. Also own this packet, your plan row, gate entry and relevant escalation/drift entries. All writes are sequential. Any minimal signed experimental host stays within your Integration helper directory, with a documented command and no production edits.

### Required seams

Read the specification, adapter decision and Provider.swift through README links. Follow existing production contracts unchanged. Use the plan's opt-in environment convention and record no private audio or secrets. Results are input to the final feasibility matrix, not authorization to implement a production design.

### Acceptance criteria

- Every S2 question has measured evidence or a concrete observed limitation, including lifecycle and availability cases above.
- Experiments run on Aidan's Mac; unsupported configurations are reported separately from supported-path evidence. Unobserved states are explicitly marked, with nondestructive evidence or an approved limitation.
- Opt-in checks are disabled in ordinary test runs, including before service initialization or asset installation.
- Framework quirks remain in test-only Apple code. Record any necessary future shared or bundle changes and why.
- Record OS/hardware/toolchain, sample/configuration, measured timings and quality tradeoffs concisely in the spec. Keep reproducible synthetic cases; avoid ceremony and exhaustive permutations.
- Independent review and focused closure pass. Discovery of an unsupported feature is valid spike evidence but must be carried to the final decision gate, never presented as feature-complete support.

### Targeted verification

On a Mac with the repository's Swift 6.2 toolchain, add tests whose names include `AppleVoiceSpike`. Run:

```bash
swift test --disable-xctest --filter AppleVoiceSpike
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleVoiceSpike
git diff --check
```

The first command confirms the opt-in tests skip without starting services. The second runs live checks; recording-based tests additionally need ECHOTYPE_FIXTURE_WAV set to an existing local WAV. Add exact recording/comparison and signed-host commands to your handoff once the candidate exists, without literal secret values. If Mac execution is unavailable, prepare the candidate and block at its Mac gate. Do not treat compilation elsewhere as live validation.

## Implementation handoff

- Base commit: TBD
- Outcome and changed files: TBD
- Decisions: TBD
- Verification and measurements: TBD
- Limitations or missing external evidence: TBD
- Specification drift: TBD

## External validation

- Gate and placement: Mac measurement, before independent review
- Status: Pending
- Candidate and exact instructions: TBD
- Required evidence: all assigned spike questions, hardware/toolchain and setup state
- Attempts and lasting decisions: TBD
- Resume condition: recorded measurements on Aidan's Mac, or explicit approved scope change

## Independent review

- Reviewer: TBD
- Verdict: TBD
- Required findings: TBD
- Optional observations: TBD
- Questions: TBD

## Resolution

- Finding dispositions: TBD
- Simplification/deletion pass: TBD
- Final verification: TBD

## Closure review

- Verdict: TBD
- Remaining required findings: TBD
