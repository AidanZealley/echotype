# Local install whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit in `plan.md` and the approved [v1 specification](../../echotype-v1.md). Inspect the accepted handoff, then independently inspect the combined diff and surrounding code. Check release bundling, signing, replacement, running-app lifecycle, login-item migration, settings status, docs, tests and the development path. Look for duplicated state, stale paths and machinery added for hypothetical failures. Classify evidence as Required, Optional or Question. Run checks proportionate to risk.

## Initial whole-feature review

- Reviewer: fresh Claude Code general-purpose agent
- Branch, base, and reviewed head: `codex/install-echotype-v1`, base `f9820dc`, reviewed head `31b8687`. The only uncommitted changes are the Final row status in `plan.md` and this file's status line.
- Verification run:
  - `bash -n scripts/*.sh` passes.
  - `swift build -c release` passes. `swift test` passes with 45 tests.
  - `codesign --verify --verbose=2 /Applications/EchoType.app` reports valid on disk and satisfies its designated requirement. The DR names `com.aidanzealley.echotype` and the leaf `Apple Development`. It is not ad hoc.
  - The installed `Info.plist` is byte-identical to `Resources/Info.plist` (`cmp`). `plutil -p` shows `CFBundleIdentifier` `com.aidanzealley.echotype` and `CFBundleExecutable` `EchoTypeApp`.
  - The installed binary's UUID `E8A89FCA-DFAE-3E7A-B1FB-49F5DFFFA79F` matches `.build/out/Products/Release/EchoTypeApp` after the fresh release build, so the candidate matches the reviewed head.
  - `ps` shows one `EchoTypeApp`, at `/Applications/EchoType.app/Contents/MacOS/EchoTypeApp`. No staged `EchoType-*.app` is left in `.build`.
  - `sfltool dumpbtm` (read-only) shows `2.com.aidanzealley.echotype` as `[enabled, allowed, notified] (0xb)` at `/Applications/EchoType.app`.
  - Repo-wide grep for `run.sh`, `install.sh`, `deploy.sh`, `.build/EchoType`, `/Applications`, login item and "only supported" outside `.build`. The results are covered below.
  - Not run, as instructed: `./scripts/install.sh`, `./scripts/run.sh`, the Settings window, any login-item change.
- Acceptance-criteria audit (plan.md "Whole-feature acceptance"):
  - `install.sh` creates a signed release bundle at `/Applications/EchoType.app` and launches it: met. `scripts/install.sh:6` calls `deploy.sh release /Applications/EchoType.app`. `deploy.sh` builds with `-c release`, stages and signs in `.build`, then stops, replaces and opens. The installed bundle, signature and running path above confirm it.
  - Build and sign stay consistent with `run.sh`, and development launches still work: met by construction. Both scripts share one `deploy.sh`, so plist copy, identity selection (`ECHOTYPE_SIGNING_IDENTITY` default `Apple Development`, as 0014 requires) and stop-before-replace cannot diverge. `run.sh:6` passes `"$@"` through. `--show-bin-path` resolves to `.build/out/Products/Debug`, which `.build/debug` symlinks to, so the debug binary is the same one the old `run.sh` copied. I did not launch it. The workstream recorded a `--hud-demo` run.
  - Enabled launch at login targets the installed app, and the toggle works from there: met. `App.swift:29-35` registers again only from `/Applications/EchoType.app` and only when `status == .enabled`. `SettingsView.swift` is unchanged and still reads and writes `SMAppService.mainApp` with no stored copy. The BTM record above and G1 confirm it.
  - `swift build -c release`, `swift test`, script checks and G1 pass: met. G1 passed on 2026-09-25 per `01-local-install.md`.
  - Docs and known gaps describe the delivered state: met. 0001 names `deploy.sh` as the one path. 0013 records the shared item and the migration. 0007 drops only the install/login gap. The spec file tree lists `deploy.sh`. `Package.swift:14-15` names all three scripts. No text anywhere still says the login item stays at `.build` after install or that `run.sh` is the only path.
- Required findings by owner: none.
- Optional observations:
  - O1, docs precision (owner: docs). Several lines still name `run.sh` where the step now lives in `deploy.sh`: `docs/specs/echotype-v1.md:456` and `docs/decisions/0014-sign-with-apple-development.md:14` ("`scripts/run.sh` selects..."), `docs/decisions/0011-settings-window-activation.md:35` ("`scripts/run.sh` stops the running instance"), and `docs/specs/echotype-v1.md:489-495`, which also says `install.sh` "copies to `/Applications`" where it now moves a staged bundle. All of them are still true in effect, because `run.sh` goes through `deploy.sh`. No change needed. A lead that wants exact wording could touch 0011:35 and spec:493 only.
  - O2, dev runs stop the installed app (owner: `scripts/deploy.sh`). `deploy.sh:34` kills every `EchoTypeApp`, so `./scripts/run.sh` also quits `/Applications/EchoType.app` and nothing relaunches it. This is intended: only one copy should hold the hotkey, and the comment at `deploy.sh:30` says so. The spec says `run.sh` "kills any running instance". Mention it only if install usage is documented for the developer.
  - O3, one path in two places (owner: `App.swift`, `install.sh`). `/Applications/EchoType.app` is a literal in `App.swift:30` and `install.sh:6`. They cannot share a constant across Swift and shell without new machinery, and the `App.swift` doc comment names the reason for the guard. No change needed.
- Questions: none.
- Verdict: Accept. No Required findings. The branch meets every whole-feature acceptance criterion. The script and Swift changes are minimal: one shared script, one-command `install.sh` and `run.sh` wrappers, and one guarded `register()` call. I found no duplicated state and no machinery for hypothetical failures.

## Lead triage

- Accepted findings and owners: none. There are no Required findings, so no correction pass ran.
- Rejected findings and reasons: none.
- Deferred optional observations:
  - O1 deferred. Every named line is still true, because `run.sh` and `install.sh` both go through `deploy.sh`. The spec already lists `deploy.sh` in its file tree, and the drift log records it. Rewording approved product documents for precision alone is not worth the churn.
  - O2 deferred. Stopping every copy is intended, so only one instance holds the hotkey, and `deploy.sh` says so. There is no install usage document for it to belong in.
  - O3 deferred. Sharing one path across Swift and shell would need new machinery for a value that does not change.
- Drift requiring user decision: none. The only drift, `scripts/deploy.sh` as the shared step, is recorded in the plan's drift log and matches the specification's "same code path" intent.

## Focused closure

- Reviewed head: `31b8687` on `codex/install-echotype-v1`, base `f9820dc`. It is the only commit since the base. The only uncommitted changes are the status and review record edits in `plan.md` and this file. No code changed after the initial review. `bash -n scripts/*.sh` passes. `swift test` passes with 45 tests. `codesign --verify --verbose=2 /Applications/EchoType.app` reports valid on disk and satisfies its designated requirement. One `EchoTypeApp` runs, from `/Applications/EchoType.app`.
- Finding outcomes: no findings were accepted, so there were no fixes to check. The three deferrals are sound. O1: the cited lines at spec 456 and 489-495, 0014:14 and 0011:35 are still true in effect, because `run.sh` and `install.sh` both call `deploy.sh`. The wording is imprecise but misleads no one about behavior. O2: `deploy.sh:30-35` stops every copy on purpose, so only one instance holds the hotkey, and the comment says so. O3: the path literal in `App.swift` and `install.sh` is fixed, and the `App.swift` guard only limits which copy claims the login item. None of them is release-blocking.
- Final simplification assessment: nothing to remove. The feature is one shared `deploy.sh`, two one-line wrappers and one guarded `register()` call. There is no duplicated state and no machinery for hypothetical failures.
- Remaining blockers: none.
- Verdict: Pass.

## Completion record

- Final verification: `bash -n scripts/*.sh`, `swift build -c release` and `swift test` (45 tests) pass. `/Applications/EchoType.app` passes `codesign --verify --verbose=2`, its `Info.plist` matches `Resources/Info.plist`, its binary matches the current release build, and one `EchoTypeApp` runs from `/Applications`. The login item is enabled at `/Applications/EchoType.app`.
- External validation pending: none. G1 passed on 2026-09-25.
- Specification drift: `scripts/deploy.sh` is the shared build, sign and launch step behind `run.sh` and `install.sh`. The spec's file tree lists it. No behavior drift.
