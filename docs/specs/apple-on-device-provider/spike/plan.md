# Apple provider spike plan

Status: approved for execution; service spikes in progress.

## Orchestration record

- Integration branch: `spike/apple-on-device-provider`
- Starting commit: `51083b55b39afd49937b2eddf466d731d7993b10`
- Specification approval reference: Aidan's 2026-10-01 instruction to execute this spike workflow from the approved HEAD. The specification and workflow baseline are committed in `51083b55b39afd49937b2eddf466d731d7993b10`; the worktree was clean at startup.
- Started: 2026-10-01
- Review method: lead subagents
- Operating instructions: [README.md](README.md)
- Scope: opt-in experiments and measured feasibility only. All three services required on a supported, configured Mac; lower quality than xAI accepted. No production implementation.

## Workstream order

| # | Workstream | Depends on | Status |
|---|---|---|---|
| 1 | [Live transcription](01-transcription.md) | Approved spike spec and workflow | Accepted |
| 2 | [Read aloud](02-voice.md) | 1 accepted | Accepted |
| 3 | [Cleanup](03-cleanup.md) | 2 accepted | Not started |
| Final | [Combined feasibility and decision](final-review.md) | 1–3 accepted | Not started |

Allow only one active lead. Each lead updates its row at each transition. A non-terminal row without a live lead is interrupted; spawn a fresh lead using README recovery rules.

## Boundaries and contracts

Each service is independently measurable and reviewable. Sequential execution avoids overlapping Mac audio, model resources, permissions and specification edits. No shared experimental framework or production availability contract is needed to answer these questions.

All streams investigate `Provider.swift` as written, especially event ordering, monotonic committed text, 16 kHz input, bounded speech pulls and cancellation. Lower quality is a measured tradeoff; missing functionality or shared Apple-specific branches is a decision-gate issue. No production provider is registered and xAI remains unchanged.

Opt-in convention: `ECHOTYPE_APPLE_SPIKE=1`. Recording convention: `ECHOTYPE_FIXTURE_WAV`. Optional xAI comparisons use `XAI_API_KEY`. Never store secrets or personal audio in tracked files.

## Ownership handoffs

Each lead owns its numbered packet, its plan row/gate entry, and its explicitly assigned experiment files and results section. Files and sections transfer only sequentially. Existing xAI tests, production source, package, resources and scripts are read-only unless an escalation approves a concrete exception. Final lead owns final-review.md, combined spec corrections, the feasibility matrix and decision record.

## Whole-spike acceptance

- S1, S2 and S3 have real measurements from Aidan's Mac and complete answers or evidenced limitations.
- Tests are opt-in; normal tests do not install assets or start Apple services.
- Experiments preserve production behavior and contain Apple-specific work within test ownership.
- Final matrix covers every updated requirement and clearly marks future app wiring as unimplemented.
- Final independent review and focused closure pass.
- Aidan's decision, provisional policies and any shared-change proposals are recorded. No production work starts.

## External validation gates

| Gate | Owner / placement | Status | Candidate / resume condition |
|---|---|---|---|
| Mac S1 | 1, before independent review | Passed | Supplied human WAV and fresh pause/prefix variants measured; approved limitations and later validation recorded in S1 handoff |
| Mac S2 | 2, before independent review | Passed | Measured missing-id/post-install inventory, bounded paused PCM, complete drain/cancel and byte-identical paragraph; Zoe provisional default and 1x accepted, offline user-reported; evidence bounds retained |
| Mac S3 | 3, before independent review | Pending | Record runnable candidate in packet; resume with S3 measurements |
| Aidan decision | Final, after closure before acceptance | Pending | Matrix and recommendation; resume with recorded user decision |

Mac gate details belong in the owning packet. If tools can run them on Aidan's Mac, complete them autonomously within authorized scope. Otherwise block with actionable commands and required evidence. Diagnostic retries follow README rules.

## Escalations

S1-evidence was resolved by the supplied human recording and Aidan's accepted limitations; its lasting decision and later validation are in the S1 handoff.

S2-evidence and S2-limitations are resolved. Aidan chose Zoe as the provisional Apple default, accepted 1x for the spike and reported a passing network-disconnected command. No repeated listening or 1.1x sample is needed. The lasting decisions, measured completeness and explicit evidence bounds are in the [S2 handoff](02-voice.md#implementation-handoff), results and drift log. Independent review and fresh closure accepted the Mac gate triage and Required R1 documentation remedy; S2 is accepted.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected streams |
|---|---|---|---|---|
| 2026-10-01 | Experiments used Swift 6.4 and SDK 27.0; packet names Swift 6.2. Human gate passed with supplied WAV and fresh pause/prefix variants; original historical fixture was not recovered. | Available toolchain on Aidan's Mac and supplied attachment. Synthetic evidence remained supplemental. | Measured environment; no requirement change approved | S1 |
| 2026-10-01 | Named unobserved S1 cases accepted with concrete later validation; no waiver of human evidence. | Aidan supplied the WAV after recovery found no historical audio. Cold loading, failed-download retry, unsupported hardware, human jargon/context limits, room silence, signed microphone/Test and unavailable xAI comparison remain explicit. | Aidan, 2026-10-01, recorded S1-evidence answer; lasting record in S1 handoff | S1 |
| 2026-10-02 | S2 used Swift 6.4 and SDK 27.0 rather than Swift 6.2. Offline execution is user-reported. | Available toolchain on Aidan's Mac; silent supported-path measurements succeeded. | Measured environment; Aidan's reported network-disconnected pass | S2 |
| 2026-10-02 | Zoe Premium is the provisional Apple default; Siri is absent. Voice setup remains Settings guidance and inventory refresh. | Aidan installed Zoe, which now resolves and synthesizes, and chose it. He identified continuous truncation; delegate completion restores the PCM tail. | Aidan's recorded Zoe choice; measured inventory and synthesis | S2 |
| 2026-10-02 | Sentence boundaries within 250 scalars replace the rejected mid-sentence break. Fixed voice-specific speed anchors are exploration, not a proven usable 0.7...1.5 range. Only offered 1x is accepted; no additional 1.1x sample. | Paragraph sentence-aware PCM equals continuous for all three voices. Aidan rejected 0.7x/1.5x and clarified: "I didn't necessarily need you to investigate 1.1x. If we're gonna have some sort of slider available in the UI eventually when we go to implement this, then I can just tweak that. I'm happy with 1x for the spike." | Aidan's 2026-10-02 clarification; future slider tuning deferred to implementation | S2 |
| 2026-10-02 | Alternate locales, full 60,000-scalar drain, signed Reader and formal xAI comparison are deferred. Actual Apple MCP wiring awaits production. Oversized-sentence prosody, failed/interrupted downloads/removal and isolated service memory remain evidence bounds with later checks in the handoff. | Aidan will explore reading lengths in real use, did not require signed Reader/formal xAI checks and requested MCP only if easy. Existing MCP checks use fake dependencies; Apple wiring needs production edits. Required availability/buffering evidence is measured nondestructively; optional states are not missing spike criteria or waived support. | Aidan's recorded scope decisions; lead triage confirmed by independent review, no authorization for destructive asset changes | S2 |
