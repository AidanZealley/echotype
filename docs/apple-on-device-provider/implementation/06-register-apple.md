# Workstream 6: Register Apple and verify it on the Mac

Status: not started.

## Task packet

### Outcome

Apple appears in the Provider tab after xAI and supplies all three services. Required permissions are in place, the spike code is gone, the documentation describes the new provider and readiness, and Aidan has verified the signed build.

Specification: [Apple provider](../../specs/apple-on-device-provider.md#apple-provider), [Spike code](../../specs/apple-on-device-provider.md#spike-code), [Verification](../../specs/apple-on-device-provider.md#verification) and [Extensibility report](../../specs/apple-on-device-provider.md#extensibility-report).

### Scope

- Add `Provider.apple`: id `apple`, name `Apple`, summary "Free. Runs on this Mac.", `Credential.none`, and the three services. Compose `Readiness` from the per-service checks and the change signal.
- Register it in `Providers.all` after xAI, so xAI stays the default.
- Settle permissions. Determine from the SDK and the signed build whether `SpeechTranscriber` needs Speech authorisation or a usage description. If it does, follow the microphone pattern:
  - add the usage text and any entitlement,
  - request at operation start,
  - word the denial in `DictationController.describe`,
  - show it in the Settings system rows.
  
  Record the evidence either way.
- Delete `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/` after confirming the production adapters and tests cover what is useful. Update the research document's Experiment code and Reproduction sections to say the experiments were removed and live in git history.
- Documentation:
  - add the extensibility report to `docs/decisions/0025-provider-adapters.md`, listing every change outside `Providers/Apple/` and `Providers.swift` with its reason and whether it belongs in the shared contract,
  - update its "Adding a provider" steps for readiness and language resolution,
  - update `README.md` where it says xAI is the only provider.
- Prepare and run gate G2, including tuning the speed range with Aidan.

### Non-goals

- Cleanup quality tuning, additional languages, and changes to the readiness contract.
- Launching or replacing Aidan's running EchoType. `scripts/run.sh` and `scripts/install.sh` stop running copies, so only Aidan runs them.

### Initial ownership

- New description file in `Sources/EchoTypeCore/Providers/Apple/`, and the Apple files only for composition fixes
- `Sources/EchoTypeCore/Providers/Providers.swift`
- `Resources/Info.plist`, `Resources/EchoType.entitlements`, plus `AudioCapture.swift`, `DictationController.swift` and `SettingsView.swift` only if a permission is required
- `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/` (deletion), `docs/research/apple-on-device-provider.md`, `docs/decisions/0025-provider-adapters.md`, `README.md`
- Apple voice and transcription files for speed-range and troubleshooting corrections during G2

### Required seams

- Consumes every earlier handoff.
- The extensibility report is the final account of shared changes for the whole-feature review.

### Acceptance criteria

- `Providers.all` is `[.xAI, .apple]`, and `Provider.xAI` is unchanged.
- The Provider tab lists Apple with three feature marks and readiness reasons, with no settings or UI change beyond workstreams 1 and 2 and any required permission row.
- The permission decision is recorded with evidence.
- The spike folder is deleted, and no link to it remains outside git history.
- The extensibility report accounts for every shared change in the branch.
- Gate G2 passes, and the tuned speed range is recorded.

### Targeted verification

```bash
swift build
swift test --disable-xctest
swift build -c release --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-ws6.app
git diff --check
```

`build-app.sh` signs a bundle at a scratch path without stopping the running app.

## External validation

- Gate and placement: G2 signed-build verification, after closure and before acceptance.
- Status: `Pending`
- Candidate and instructions: the closure-accepted branch. Aidan runs `./scripts/run.sh` and works through every item in the specification's [Verification](../../specs/apple-on-device-provider.md#verification) list. He also sets the speed range by ear for Zoe and Jamie: the lead offers candidate endpoints, and Aidan picks them.
- Required evidence: pass or failure for each verification item, the chosen speed range, and the speech permission prompt behaviour.
- Attempts and lasting decisions: `TBD`
- Resume condition: every verification item passes and the speed range is chosen.

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
