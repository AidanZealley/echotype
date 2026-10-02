# Spike 3: Cleanup

Status: Accepted. Mac gate, independent review and fresh closure passed under Aidan's availability policy. Frozen task packet approved through the workflow.

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

- Base commit: `567a959a2353e5e8632fd5a2136421eb627a9ce6`.
- Outcome and changed files: added `Tests/EchoTypeCoreTests/Integration/AppleCleanupSpike.swift` and `Integration/AppleCleanup/SpikeCleanup.swift`. Added `S3 results` immediately after the specification questions and this handoff. The lead's existing plan status edit was preserved. No production or xAI files changed.
- Decisions: one fresh session per request with the exact neutral prompt, greedy generation and default protections. Real Reviser owns windows, validation and the final timeout. No text truncation, shared machinery, signed host or asset installation. Removed redundant mock preservation probes because real rejected replies, framework context failures and cancellation already demonstrate that behavior. Accumulated commits extend their previous prefix.
- Verification and measurements: ordinary opt-in test skips before model/service initialization. Apple-only live runs pass on Aidan's Mac with Swift 6.4/SDK 27.0. Final implementation live run took 42.419 s. Returned-text token counts do not claim aborted model generation usage. Process-first final and network-denied process runs also pass. `git diff --check` passes. Detailed timing, quality, context and language evidence is in `S3 results`; no raw input or logs are tracked.
- Evidence locations outside the repo: `/tmp/echotype-s3-disabled-final.log`, `/tmp/echotype-s3-live.log`, `/tmp/echotype-s3-first-final.log`, `/tmp/echotype-s3-network-denied-retry.log`, `/tmp/echotype-s3-final.log`. Inputs are reproducible synthetic strings in the tests. No API key was available or used.
- Limitations or missing external evidence: Aidan supplied a passing 42.127-second run in response to the requested host-disconnected check on 2026-10-02. Retain that as user-reported offline evidence, consistent with S2, without claiming agent-observed networking. A network-denied child also passed, but the system model daemon is outside its sandbox. A configured available Mac cannot nondestructively measure `deviceNotEligible`, disabled Apple Intelligence, model download/not-ready or a truly unloaded cold model. Process-first timings do not establish those states. Aidan's later policy accepts these named evidence bounds where supported-path measurements establish feasibility. Supported-language inventory is measured, English quality only. Harmful accepted deletions remain a decision-gate quality risk. No xAI comparison.
- Recovery audit, 2026-10-02: HEAD and candidate base both remain `567a959a2353e5e8632fd5a2136421eb627a9ce6`. All dirty changes belong to S3 experiments and their assigned records, including the orchestrator's user answer. Existing final, process-first and network-denied logs match the handoff. Recovery reran `swift test --disable-xctest --filter AppleCleanupSpike`: the suite and its one test skipped in 0.001 seconds, before model initialization. `git diff --check` passed. Preserve the candidate. Aidan's reported offline pass resolves the request for another run. That earlier offline answer did not decide the named cold/unavailable-state limitation. The later policy decision resolves it as recorded below.
- Resumed implementation audit, 2026-10-02 after the policy decision: inherited tests and logs match the packet and unchanged cleanup contract. Preserved both experiment files without adding machinery. The disabled suite and test skip in 0.001 s before model initialization; the fresh live run passes in 47.129 s on the same Mac/OS/toolchain and available 4,096-token model. Logs are `/tmp/echotype-s3-policy-disabled.log` and `/tmp/echotype-s3-policy-live.log`. Short-case final results again match 6 of 7 original expectations and 8 of 11 overall. First live takes 2.805 s; subsequent short live takes 0.615–1.261 s, short final 0.511–1.384 s. Live/final cancellation joins in 0.214/0.303 ms. The distinct passage and oversized final preserve text at 3.097/3.210 s; accumulated finish preserves the full original in 2.992 s after a real context failure, and slow accumulation retains its pending tail in 3.077 s. Existing process-first and bounded network-denied evidence remains valid. `git diff --check` passes. Real revision and preservation establish supported-path feasibility; destructive accepted deletions and timeout overrun remain final-decision tradeoffs, not missing functionality.
- Lasting policy: unsupported hardware and disabled Apple Intelligence are hard availability gates. Required models must be present and Apple Intelligence enabled before the feature can be used. Loading and downloading/not-ready states need appropriate user messaging in the pill; do not add unavailable-state fallback machinery. This approves the named cold/unavailable-state evidence bounds on existing supported-path evidence without approving production changes or system-state manipulation. The final lead must reconcile the older cleanup-only fallback proposals in Step 2 and Verification with this policy before the final decision. Individual failed/oversized/unfaithful requests retain Reviser's existing text-preservation behavior.
- Specification drift: Swift 6.4 and SDK 27.0 were available, rather than the packet's Swift 6.2. Aidan's later availability policy supersedes the original unavailable-cleanup fallback proposal; no production implementation, ownership change or shipping decision was made by this implementation agent.

Exact checks from the repository root:

```bash
swift test --disable-xctest --filter AppleCleanupSpike
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleCleanupSpike
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_CLEANUP_FINAL_FIRST=1 swift test --disable-xctest --filter AppleCleanupSpike
git diff --check
```

Nondestructive networking-denied process check, after a normal build:

```bash
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_CLEANUP_FINAL_FIRST=1 \
  sandbox-exec -p '(version 1) (allow default) (deny network*)' \
  swift test --disable-sandbox --skip-build --disable-xctest --filter AppleCleanupSpike
```

The first attempt without SwiftPM `--disable-sandbox` failed with `sandbox_apply: Operation not permitted` while compiling the manifest. The retry only disables SwiftPM's nested build sandbox; the outer process network denial stays active. It does not disable Foundation Models protections. No recording/comparison or signed-host command is needed: S3 consumes synthetic text and works directly in SwiftPM.

## External validation

- Gate and placement: Mac measurement, before independent review.
- Status: Passed. Supported-path measurements passed and offline execution is user-reported. Lead accepts explicit cold/unavailable-state bounds under Aidan's 2026-10-02 policy.
- Candidate and exact instructions: uncommitted files listed above, based on `567a959`. Build and run the documented ordinary/live commands. The requested host-disconnected command was `ECHOTYPE_APPLE_SPIKE=1 swift test --skip-build --disable-xctest --filter AppleCleanupSpike`. Aidan supplied its passing summary; another offline run is not required. The agent has not toggled networking or system settings.
- Required evidence: satisfied by supported-path measurements and the approved evidence bounds. OS/hardware/toolchain, current availability and representative locale support are measured. No concrete unresolved supported-path feasibility question requires further unavailable-state investigation.
- Attempts and lasting decisions: real Mac tests, successful model edits, unwanted deletion, rejected replies, long/oversized requests, accumulated slow work, live/final cancellation and total finish joining are measured. Child-process network denial passed. Aidan's 42.127-second reported pass resolves the offline check at the same evidence standard accepted for S2. Aidan's later explicit policy accepts the named bounds where supported-path evidence suffices; lead applies that decision without claiming measured unavailable transitions.
- Gate disposition: proceed to independent review. Retain harmful deletion and timeout tradeoffs in the final feasibility decision. No production or system-state changes are authorized.

## Independent review

- Reviewer: fresh independent S3 reviewer, 2026-10-02. Read the packet, workflow, plan, feature specification, adapter decision, Provider.swift and Reviser. Inspected the complete candidate against `567a959`, including both untracked experiment files.
- Verdict: Pass for S3 feasibility under Aidan's recorded availability policy. No S3 blocker. This does not decide shipping quality or authorize production work.
- Required findings: none. Real model edits establish cleanup functionality; the helper creates a fresh session for each request with the exact neutral prompt and default protections. Reviser retains ownership of windows, validation and the final deadline. Ordinary execution skips before model/service initialization. Changes stay within S3 test and documentation ownership, with no production, registry, package or xAI edits.
- Verification: independently reran the ordinary command, which skipped the suite and test in 0.001 s, and the live command, which passed in 43.245 s. `git diff --check` passed. The live log is `/tmp/echotype-s3-independent-live.log`. The reviewer also checked the supplied 47.129 s policy run, process-first final and network-denied child logs against their recorded summaries. The independent run again produced the documented corrections and harmful deletions, 6 of 7 original expected final results and 8 of 11 overall. Distinct/oversized final inputs preserved text at 3.038/3.209 s; accumulated finish preserved all text at 3.075 s after a real context failure. Slow accumulation retained its pending tail at 3.200 s. Live/final cancellation joined in 0.220/0.256 ms and retained text.
- Optional observations: carry the accepted destructive deletions and deadline overrun into the final quality decision as already recorded. The Jane correction selects John in the final result, the preservation sentence reduces to `Sorry`, and the repeated long passage reduces to one clause. Passing faithfulness validation does not establish semantic preservation. These measured quality limitations do not justify a prompt/validator change or a cleanup omission within this spike.
- Questions: none within S3. Only available-state English quality is measured. Process-first timing does not prove an unloaded model; process network denial does not cover the system model daemon; host-wide offline evidence remains user-reported. The records distinguish these bounds from measurements and apply Aidan's accepted cold/unavailable-state policy without claiming tested transitions. Reconciliation of the older Step 2/Verification fallback proposals remains the final lead's assigned work.

## Resolution

- Finding dispositions: lead validates the independent Pass against the packet and unchanged production contract. No Required or Question findings; no remediation is needed. Optional harmful deletion and deadline observations remain explicit final-decision tradeoffs.
- Simplification/deletion pass: implementation agent removed redundant mock preservation probes. Production source and xAI cases are unchanged; fresh-session helper is test-only.
- Final verification and acceptance: lead inspected candidate and fresh implementation/independent ordinary/live logs. Fresh closure passes with no Required findings. Real revision, preservation, cancellation and containment satisfy S3 under the approved bounds. `git diff --check` passes. Accepted investigation evidence only; no shipping decision or production implementation.

## Closure review

- Reviewer: fresh focused S3 closure reviewer, 2026-10-02. Read the same packet and source-of-truth documents as independent review, inspected the complete candidate against `567a959`, including both untracked experiment files, and checked the accepted finding dispositions.
- Verdict: Pass for S3 feasibility under Aidan's recorded availability policy. No remediation was required. Real corrections, request failure preservation, cancellation and accumulated-window evidence satisfy the packet within its approved bounds. This is not a shipping decision or authorization for production work.
- Remaining required findings: none. The helper uses fresh sessions, the exact neutral prompt and unchanged protections. Reviser still owns windows, validation and the final budget. All candidate changes remain in S3 experiments and assigned records; production, registry, package and xAI files are unchanged.
- Verification: reran `swift test --disable-xctest --filter AppleCleanupSpike`; the suite and test skipped in 0.001 s before model/service initialization. `git diff --check` passed. Inspected the independent 43.245 s and implementation 47.129 s live logs, which confirm real edits, rejected replies, preservation on context failure/timeout, pending-tail preservation and prompt cancellation. No new defect or code change justified repeating live execution.
- Evidence bounds and final handoff: harmful accepted deletions and completion beyond the 3 s cancellation deadline remain explicit final quality tradeoffs. Only available-state English quality is measured; genuine cold timing and unavailable-state transitions remain accepted bounds, and host-wide offline execution remains user-reported. Unsupported hardware and disabled Apple Intelligence are hard gates; required models must be present, loading/not-ready states need pill messaging, and no unavailable-state fallback machinery is proposed. The final lead still owns reconciliation of the older Step 2/Verification fallback text before the final decision. None of these assigned final-gate items is an unresolved S3 blocker.
