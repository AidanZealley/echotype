# Spike 3: Cleanup

Status: not started. Frozen task packet, subject to workflow approval.

## Task packet

### Outcome

Measured feasibility for S3 against the feature-complete Apple fallback requirement. Record answers and proposed implementation choices in the assigned specification results section, with no production implementation.

### Scope

Answer every S3 question using the exact neutral Reviser.prompt. Run the existing revision cases with synthetic correction and preservation cases, recording actual edits, unwanted deletion, unchanged replies, faithfulness rejection and failures. Exercise a test-only CleanupService through Reviser where needed. Show successful real revision; an always-unchanged stub is not feature completeness. Exact xAI wording and success rate are not required.

Measure cold/warm live and final latency, cancellation latency and total stop-to-result latency including joining live work. Test fresh model sessions, long unpunctuated input and accumulated windows, accounting for instructions and generated output in context limits. Verify failed/oversized/unfaithful requests preserve text through existing behavior. Record supported-language and Apple Intelligence availability states and offline operation. Do not disable framework protections or change the shared prompt/validator to manufacture success.

### Non-goals

Production adapters, registry changes, shared contract changes, UI, deployments and production implementation packets. Do not reject solely for quality below xAI or silently omit required features. Do not promise behavior supported only by documentation or mocks.

### Initial ownership

Tests/EchoTypeCoreTests/Integration/AppleCleanupSpike.swift and test-only helpers under Integration/AppleCleanup/. Own the spec section `S3 results` immediately after S3 questions. Read existing revision cases without refactoring xAI tests. Do not change Reviser or production cleanup services. Also own this packet, your plan row, gate entry and relevant escalation/drift entries. All writes are sequential. Any minimal signed experimental host stays within your Integration helper directory, with a documented command and no production edits.

### Required seams

Read the specification, adapter decision and Provider.swift through README links. Follow existing production contracts unchanged. Use the plan's opt-in environment convention and record no private audio or secrets. Results are input to the final feasibility matrix, not authorization to implement a production design.

### Acceptance criteria

- Every S3 question has measured evidence or a concrete observed limitation, including lifecycle and availability cases above.
- Experiments run on Aidan's Mac; unsupported configurations are reported separately from supported-path evidence. Unobserved states are explicitly marked, with nondestructive evidence or an approved limitation.
- Opt-in checks are disabled in ordinary test runs, including before service initialization or asset installation.
- Framework quirks remain in test-only Apple code. Record any necessary future shared or bundle changes and why.
- Record OS/hardware/toolchain, sample/configuration, measured timings and quality tradeoffs concisely in the spec. Keep reproducible synthetic cases; avoid ceremony and exhaustive permutations.
- Independent review and focused closure pass. Discovery of an unsupported feature is valid spike evidence but must be carried to the final decision gate, never presented as feature-complete support.

### Targeted verification

On a Mac with the repository's Swift 6.2 toolchain, add tests whose names include `AppleCleanupSpike`. Run:

```bash
swift test --disable-xctest --filter AppleCleanupSpike
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleCleanupSpike
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
