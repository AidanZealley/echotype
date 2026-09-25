# Local install implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Integration branch: `TBD`
- Starting commit: `TBD`
- Review command: lead subagents
- Specification approved at commit: `TBD`
- Started: `TBD`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Install a signed release app](01-local-install.md) | Approved v1 spec and current settings implementation | Not started |
| Final | [Whole-feature review](final-review.md) | Workstream 1 and gate G1 | Not started |

## Why this boundary

Release bundling, replacement of the installed app and launch-at-login registration share the same app path. A script that installs successfully but leaves a login item pointing at `.build` is incomplete, so one lead owns the whole change. The final review is independent of that lead's review.

## Cross-workstream contracts and ownership handoffs

- The bundle identifier in `Resources/Info.plist`, the Keychain service and the `UserDefaults` domain remain stable.
- `scripts/run.sh` remains the development launch path. Workstream 1 may factor out the common bundle/sign steps only if the direct release script would otherwise duplicate fragile signing logic. The final-review lead may change workstream-owned files for accepted corrections.
- An enabled login item must resolve to `/Applications/EchoType.app` after installation. The settings toggle continues to reflect `SMAppService.mainApp`, not a second stored preference.

## Whole-feature acceptance

- `install.sh` creates a signed release bundle at `/Applications/EchoType.app` and launches it.
- Build/sign behavior stays consistent with `run.sh`; development launches still work.
- Existing enabled launch-at-login state targets the installed app, and the settings toggle works from there.
- `swift build -c release`, `swift test`, focused script checks and gate G1 pass.
- Documentation and the known-gaps record describe the delivered state.

## External validation gates

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1 Installed login behavior | Workstream 1 | After closure, before acceptance | Pending | `/Applications/EchoType.app` built by `install.sh`; record date and verification in packet | The developer confirms enable and disable behavior across real login, or supplies a failure for repair |

## Escalations

Empty until a lead blocks. Each entry must give the decision or evidence needed, realistic options, recommendation, supporting evidence, what it unblocks, and the developer's answer. A resuming lead records a lasting decision in its handoff and this plan's drift log where relevant, then removes the resolved entry.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| — | None | — | — | — |
