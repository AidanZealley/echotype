# Workstream 1: Install a signed release app

Status: accepted.

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

- Base commit: `f9820dc`
- Outcome: `./scripts/install.sh` builds in release mode, assembles and signs the bundle in `.build/EchoType-release.app`, stops every running EchoType, replaces `/Applications/EchoType.app` and opens it. The installed app moves an enabled login item to itself at launch and leaves a disabled one disabled. `./scripts/run.sh` behaves as before, and its arguments still reach the app.
- Files changed:
  - `scripts/deploy.sh` (new): the shared build, bundle, sign, stop, replace and launch step. Usage: `deploy.sh <debug|release> <app path> [args...]`. Both paths share it because the plist copy, signing identity selection and stop-before-replace are what must not diverge. It stages and signs before stopping the running app, so a failed build or signature leaves the existing bundle in place.
  - `scripts/run.sh`: now `deploy.sh debug .build/EchoType.app "$@"`.
  - `scripts/install.sh` (new): `deploy.sh release /Applications/EchoType.app`.
  - `Sources/EchoTypeApp/App.swift`: `claimLoginItem()`. Only when the bundle path is `/Applications/EchoType.app`, off the main actor, it calls `SMAppService.mainApp.register()` if `status == .enabled`.
  - `docs/decisions/0001`: `deploy.sh` is the one build path, used by both scripts. `0013`: the login item's consequence now describes the observed path behaviour and the migration. `0007`: removed the install/login gap.
- Decisions: I chose the login-item migration from what `sfltool dumpbtm` showed on macOS 27.2 (entry `2.com.aidanzealley.echotype`):
  - Before this work the item was `[enabled, allowed, notified]` with URL `/Users/501/code/echotype/.build/EchoType.app`. The installed app, built without migration code, showed the toggle on, because `status` answers by bundle identifier while the item still pointed at `.build`. Launching a copy does not move the URL, even after 20 seconds.
  - Reading `status` from a copy moves the URL to that copy and keeps the enabled or disabled state. Opening Settings in the development bundle moved an enabled `/Applications` item to `.build`. A probe build of the installed app that only read `status` at launch moved it back.
  - `register()` from the installed copy while the item is enabled leaves it enabled at `/Applications/EchoType.app`. `unregister()` and `register()` from the Settings toggle produce `0xa` (disabled) and `0xb` (enabled) at the calling copy's path.
  - So the smallest reliable migration is for the installed app to call the documented `register()` at launch when the item is enabled. Relying only on the undocumented side effect of reading `status` would be fragile. Anything done from the script cannot work, because only the app can call `SMAppService.mainApp` for itself. The path guard stops `run.sh` launches from taking the item. The development bundle still takes it if its Settings window is opened, and the next installed launch takes it back. `0013` records this.
- Verification:
  - `swift build -c release` passed. `swift test` passed (45 tests). `bash -n scripts/run.sh scripts/install.sh scripts/deploy.sh` passed.
  - `./scripts/install.sh` ran three times, most recently after the final code change. The installed `Info.plist` is byte-identical to `Resources/Info.plist`, and `plutil -p` shows `com.aidanzealley.echotype` and `EchoTypeApp`. The installed binary has the same `LC_UUID` as `.build/out/Products/Release/EchoTypeApp`.
  - `codesign --verify --verbose=2` reports the bundle valid and satisfying its designated requirement. The authority is `Apple Development` and the DR includes the bundle identifier.
  - `ps` and `lsof` show exactly one `EchoTypeApp`, at `/Applications/EchoType.app/Contents/MacOS/EchoTypeApp`, after each install and after installs that followed dev runs. No `EchoType-*.app` staging bundle is left in `.build`.
  - In the installed app's Settings, both permission rows read Granted and the saved API key shows masked, so TCC and Keychain identity carried over.
  - `./scripts/run.sh --hud-demo` launched `.build/EchoType.app/Contents/MacOS/EchoTypeApp --hud-demo` and did not move the item at launch. Plain `./scripts/run.sh` also ran.
  - I drove the login cases through the settings UI with System Events and read the result with `sfltool dumpbtm`:
    - Enabled at `.build`, then install: enabled at `/Applications`. Proved twice.
    - Disabled at `.build`, then install: still disabled.
    - The installed toggle reads the OS state after each change and switches it between `0xa` and `0xb`.
  - The final candidate is running from `/Applications`, with Launch at login enabled at `/Applications/EchoType.app`, which matches the enabled state the item had before this work.
- Known limitations or external checks:
  - G1 must confirm that a real login starts `/Applications/EchoType.app` when the item is enabled and starts nothing when it is disabled. The agent could only prove the BTM record, not a login.
  - The unified log redacts BTM activity, so I could not check whether `register()` on every installed launch, including at login, shows a login-item notification. G1 should note any repeated "Login item added" notification.
  - I never saw `requiresApproval`.
  - The `Package.swift` comment still names only `scripts/run.sh` as the launch path. The file is outside this packet's ownership.
- Specification drift: The specification's file tree lists `run.sh` and `install.sh`. This adds `scripts/deploy.sh` as their shared step, which matches the specification's "same code path" intent. There is no behaviour drift.

## Independent review

- Reviewer: fresh Claude Code general-purpose agent
- Verdict: Accept. No Required findings. The diff meets acceptance criteria 1 to 5 as far as an agent can prove them. G1 still has to cover a real login.
- Evidence checked:
  - `bash -n` passes on all three scripts. `swift build -c release` passes, and `swift test` passes with 45 tests.
  - The installed `Info.plist` is byte-identical to `Resources/Info.plist`, with `com.aidanzealley.echotype` and `EchoTypeApp`.
  - `codesign --verify --verbose=2` reports `/Applications/EchoType.app` valid and satisfying its DR. The DR names the bundle identifier and the `Apple Development` leaf, and it is not ad hoc.
  - The installed binary's UUID matches `.build/out/Products/Release/EchoTypeApp` (`E8A89FCA-…`).
  - One `EchoTypeApp` is running, from `/Applications/EchoType.app/Contents/MacOS/EchoTypeApp`. No staged `EchoType-*.app` is left in `.build`.
  - `sfltool dumpbtm` shows `2.com.aidanzealley.echotype` as `[enabled, allowed, notified]` at `/Applications/EchoType.app`.
  - `run.sh` keeps `"$@"` passthrough. An empty `"$@"` is safe under `set -u` on the system bash 3.2.
  - `deploy.sh` signs before it stops the running app, so a failed build or signature leaves the installed bundle and the running app alone.
  - A missing argument fails at `$1`/`$2` under `set -u` before any build or delete.
  - The identity selection is copied verbatim from the old `run.sh`, which satisfies 0014.
  - The login-item approach is minimal and sound. The app is the only process that can act as `SMAppService.mainApp`. The call is the documented `register()`, gated on `.enabled`, so a disabled item is never re-enabled. It runs off the main actor like the settings row, and the path guard keeps `run.sh` launches from claiming the item. `SettingsView.swift` is unchanged, so the toggle still reads and writes the live service status.
  - The docs agree with the code. 0001 names `deploy.sh`. 0013 records the observed path behaviour and the migration. 0007 removes only the install/login gap. 0011's "`run.sh` stops the running instance" is still true through `deploy.sh`.
- Required findings: none.
- Optional observations:
  - O1, stale comment: `Package.swift:14` still says the app is "Built into a signed .app bundle by scripts/run.sh, which is the only supported way to launch it". It now also goes through `install.sh` via `deploy.sh`. This is outside initial ownership. The lead could extend ownership by one line to name `scripts/deploy.sh`, or leave it for the final review.
  - O2, specification drift: `docs/specs/echotype-v1.md` lists only `run.sh` and `install.sh` in its file tree (lines 388-389) and development workflow (lines 485-493). The handoff records `deploy.sh` as drift. The lead should decide whether the spec gets a one-line mention or the drift log is enough.
  - O3, replacement window: `deploy.sh` does `rm -rf "$app"` and then `mv "$staged" "$app"` after killing the app. If `rm` fails part way, for example on a bundle left root-owned by an earlier `sudo` install, the script exits with the old instance stopped and a partial bundle in `/Applications`. Rerunning after fixing ownership recovers it, and the normal admin-user case is fine. Not worth extra machinery. Mention it only if install troubleshooting is documented.
  - O4, unbounded wait: the `pgrep` loop is carried over unchanged from `run.sh` and never times out. A hung EchoType that ignores SIGTERM would stall `install.sh` silently. This behaviour predates the workstream.
- Questions:
  - Q1: `claimLoginItem()` calls `register()` on every installed launch, including launches from the login item. The BTM record stays `notified`, which suggests macOS will not repeat the "Login item added" notification, but the agent cannot prove it. Keep this as an explicit G1 observation, as the handoff already proposes.

## Resolution

- Finding dispositions:
  - No Required findings, so no correction pass ran.
  - O1 accepted. The lead extended ownership by one comment line in `Package.swift` so it names `deploy.sh`, `run.sh` and `install.sh`.
  - O2 accepted. `scripts/deploy.sh` added to the specification's file tree. The workflow prose already says both scripts share one code path, so it stays. Recorded in the plan's drift log.
  - O3 deferred. A root-owned bundle from a previous `sudo` install is not a supported state, and a rerun after fixing ownership recovers it.
  - O4 deferred. The wait predates this workstream and a hung app is visible to the person running the script.
  - Q1 carried into G1 as an explicit observation.
- Simplification/deletion pass: `run.sh` lost its duplicated build and sign steps to `deploy.sh`. `install.sh` is one line. The Swift change is one guarded call. Nothing further to remove.
- Final verification: `swift build` passed after the lead's comment edit. The implementation and review checks stand for everything else, since the lead's edits are comments and documentation only.
- Closure bookkeeping: the `scripts/deploy.sh` row is in the `plan.md` drift log.
- Acceptance audit (resuming lead, after G1): the uncommitted diff matches this record on base `f9820dc`, and nothing changed after closure. `bash -n` on all three scripts, `swift build -c release` and `swift test` (45 tests) pass. `/Applications/EchoType.app` verifies with `codesign`, its `Info.plist` is byte-identical to `Resources/Info.plist`, its binary UUID `E8A89FCA-…` matches the current release build, and one `EchoTypeApp` is running from `/Applications`.

## Closure review

- Verdict: Pass. The O1 and O2 fixes are correct, and nothing in the workstream blocks release against acceptance criteria 1 to 5. G1 still has to prove a real login. `bash -n scripts/*.sh`, `swift build -c release` and `swift test` (45 tests) pass.
- Remaining required findings: none. One bookkeeping gap for the lead, which does not block release: the Resolution says O2 is "Recorded in the plan's drift log", but the `plan.md` drift log still reads `None`. Add the `scripts/deploy.sh` row or correct that sentence.

## External validation

- Gate and placement: G1, after closure and before acceptance.
- Status: Passed on 2026-09-25.
- Candidate and instructions: `/Applications/EchoType.app`, installed by `./scripts/install.sh` from the workstream diff on base `f9820dc`. The lead's later edits were comments and documentation only, so the installed binary matches the current code. Local evidence on 2026-09-25:
  - One `EchoTypeApp` running, from `/Applications/EchoType.app/Contents/MacOS/EchoTypeApp`.
  - `codesign --verify --verbose=2`: valid on disk and satisfies its designated requirement. `CFBundleIdentifier` is `com.aidanzealley.echotype`.
  - `sfltool dumpbtm`: `2.com.aidanzealley.echotype` is `[enabled, allowed, notified] (0xb)` at `/Applications/EchoType.app`.

  Developer steps:
  1. Open Settings in the running EchoType and confirm Launch at login is on. Do not open Settings from a `./scripts/run.sh` build before testing, because that moves the login item to `.build`.
  2. Sign out and back in, or restart. Confirm EchoType starts, and that `ps -axo command | grep '[E]choTypeApp'` shows `/Applications/EchoType.app/Contents/MacOS/EchoTypeApp`. Note any "Login item added" notification (Q1).
  3. Turn Launch at login off in Settings. Sign out and back in again. Confirm EchoType does not start.
  4. Note whether macOS asked for approval in System Settings > General > Login Items at any point.
- Required evidence: The developer's pass/fail for both enabled and disabled cases, plus the observed app path or concrete failure.
- Attempts and lasting decisions: Attempt 1 offered and passed on 2026-09-25. The developer reported that with Launch at login enabled from the installed app, EchoType started at the next login from `/Applications`, and with it disabled, it did not start. No "Login item added" notification or approval prompt appeared at either login. That answers Q1: calling `register()` at every installed launch does not repeat the notification.
- Resume condition: Evidence recorded in the plan escalation; a fresh lead audits the candidate and resolves any failure before marking G1 Passed.
