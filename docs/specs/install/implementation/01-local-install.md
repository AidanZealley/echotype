# Workstream 1: Install a signed release app

Status: not started.

## Task packet

### Outcome

Running `./scripts/install.sh` builds EchoType in release mode, installs a signed bundle in `/Applications`, and launches the installed app. An enabled Launch at login setting starts the installed copy at the next login.

### Scope

- Add `scripts/install.sh` using the same bundle, plist and stable signing identity as `scripts/run.sh`. Reuse a shared step only if duplication would make the two paths likely to diverge.
- Handle an already running EchoType and replacement of an existing installed bundle without leaving the app registered or launched from `.build`.
- Preserve or re-establish an enabled `SMAppService.mainApp` registration from `/Applications/EchoType.app`. Keep the settings row reading the service's actual status. Decide the smallest reliable migration from a prior `.build` registration using the macOS API and observed behavior; record the choice.
- Update the relevant decision and known-gaps documents to match the implementation.

### Non-goals

- Notarization, Developer ID distribution, installer packages, auto-update, and changes to unrelated known gaps.
- A second login preference in `UserDefaults` or a general deployment framework.

### Initial ownership

- `scripts/install.sh`, `scripts/run.sh`, and any small shared script they require.
- `Sources/EchoTypeApp/Views/SettingsView.swift` and `Sources/EchoTypeApp/App.swift` only for installed login-item migration or status handling.
- `docs/decisions/0001-build-and-sign-on-the-mac.md`, `docs/decisions/0013-test-button-and-system-rows.md`, `docs/decisions/0007-known-gaps.md`, and a new decision record only if a lasting install-specific choice needs one.
- This packet's record sections and the workstream row, gate and drift entries in `plan.md`.

### Required seams

- The bundle identifier stays as set in `Resources/Info.plist`; the executable remains `EchoTypeApp`.
- The stable code-signing identity used by `run.sh` signs both builds.
- `run.sh` selects a local Apple Development identity, with `ECHOTYPE_SIGNING_IDENTITY` for multiple matches. Make `install.sh` follow that same selection as recorded in decision 0014.
- The installed bundle is the source of `SMAppService.mainApp` registration. The settings UI remains the user's control for enabling and disabling it.
- Keep release output in `.build` until the candidate is ready to replace `/Applications/EchoType.app`.

### Acceptance criteria

1. `./scripts/install.sh` exits successfully with a signed release binary, the current `Info.plist`, fixed bundle ID and installed path. It launches that copy, not the development bundle.
2. Repeating the command replaces and relaunches the installed copy without losing its stable TCC/Keychain identity or leaving duplicate running instances.
3. An existing enabled login item that previously pointed at `.build/EchoType.app` is re-associated with the installed copy. An intentionally disabled login item stays disabled. The settings toggle still reports the actual OS state and can change it.
4. `./scripts/run.sh` still builds, signs and launches the development bundle, including `--hud-demo` argument passing.
5. Docs remove the resolved install/login gap without claiming unrelated gaps are fixed.

### Targeted verification

- `swift build -c release`
- `swift test`
- `bash -n scripts/run.sh scripts/install.sh`
- Run `./scripts/install.sh`, then inspect `/Applications/EchoType.app/Contents/Info.plist` with `plutil`, the binary path and signature with `codesign --verify --verbose=2`, and the running app path with `ps` or `lsof`.
- Run `./scripts/run.sh --hud-demo` once to check the development path, then reinstall the release candidate if that changed the login-item target.
- Verify enabled and disabled login states locally through the settings UI and `SMAppService` status. Record which cases macOS allowed the agent to prove. G1 covers the next real login.

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

- Gate and placement: G1, after closure and before acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`. Use the installed app's Settings to enable Launch at login. At the next sign-out and login or restart, confirm the running EchoType path is `/Applications/EchoType.app`. Disable the toggle and confirm a later login does not start EchoType. Record if macOS required approval in Login Items.
- Required evidence: The developer's pass/fail for both enabled and disabled cases, plus the observed app path or concrete failure.
- Attempts and lasting decisions: `TBD`
- Resume condition: Evidence recorded in the plan escalation; a fresh lead audits the candidate and resolves any failure before marking G1 Passed.
