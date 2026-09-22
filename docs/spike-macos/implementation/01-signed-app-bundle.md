# Workstream 1: Signed app bundle and run script

Status: accepted.

## Task packet

### Outcome

`./scripts/run.sh` builds the package, assembles a `.app` bundle, signs it with the
`EchoType Dev` identity, kills any running instance and launches it. A waveform icon
appears in the menu bar with a working Quit item. Nothing else happens yet.

### Scope

- `Package.swift` at swift-tools-version 6.2, platform `.macOS(.v26)`, one executable
  target named `EchoTypeApp`. No dependencies.
- `Sources/EchoTypeApp/` containing a SwiftUI `App` using `MenuBarExtra` with the SF
  Symbol `waveform` and a Quit item.
- `Resources/Info.plist` with `CFBundleIdentifier` `com.aidanzealley.echotype`,
  `CFBundleName`, `CFBundleExecutable`, `CFBundlePackageType`, a version, and
  `LSUIElement` set true so nothing appears in the Dock or Cmd+Tab.
- `scripts/run.sh` doing build, bundle assembly, signing, kill and relaunch. Suggestion:
  `set -euo pipefail`, build with `swift build`, assemble into `.build/EchoType.app`
  with the standard `Contents/MacOS` and `Contents/Info.plist` layout, sign with
  `codesign --force --sign "EchoType Dev"`, then `open` the bundle.

### Non-goals

- Any event tap, hotkey, pasteboard or audio code. That is workstream 2.
- App Sandbox and hardened runtime. The specification excludes both, and the sandbox
  would break the event tap that workstream 2 adds.
- An entitlements file. Nothing in the spike needs one.
- Notarization, a Developer ID certificate, or any distribution step.
- An `.xcodeproj`. The specification rejects it.
- An app icon asset. `waveform` is the placeholder.

### Initial ownership

Creates and owns `Package.swift`, `Sources/EchoTypeApp/`, `Resources/Info.plist` and
`scripts/run.sh`. Touches nothing else.

### Required seams

Frozen for workstream 2: the bundle identifier, the `EchoType Dev` signing identity,
`scripts/run.sh` as the only build and launch path, and the single executable target.

### Acceptance criteria

1. `swift build` succeeds on macOS 26.
2. `./scripts/run.sh` completes without error and launches the app.
3. A waveform icon appears in the menu bar and its Quit item terminates the app.
4. Nothing appears in the Dock or the Cmd+Tab switcher.
5. `codesign -dv --verbose=4` on the built bundle reports the `EchoType Dev`
   authority and `com.aidanzealley.echotype` as the identifier.
6. Running `./scripts/run.sh` twice in a row works, with the second run replacing the
   first instance rather than launching a duplicate.

### Targeted verification

```bash
swift build
./scripts/run.sh
codesign -dv --verbose=4 .build/EchoType.app
security find-identity -v -p codesigning
```

No unit tests. There is no logic here to test, and a test asserting that a shell
script ran would protect nothing.

## External validation

- Gate and placement: G1 before verification, G2 after closure and before acceptance.
- Status: `Passed` (G1 and G2)
- Candidate and instructions: see the External validation gates section of
  [plan.md](plan.md).
- Required evidence: `security find-identity -v -p codesigning` lists `EchoType Dev`;
  the menu bar icon appears; `codesign -dv --verbose=4` reports the expected authority
  and identifier.
- Candidate: the uncommitted workstream on `spike/macos-hotkey-paste` (base
  `2c57765`), after closure.
- Attempts and lasting decisions: attempt 1 not run. The lead found the Swift
  toolchain unusable (Command Line Tools swift-driver missing `llbuild.framework`;
  Xcode 27 installed but its license not accepted) and no `EchoType Dev` identity.
  Escalated as E1 with G1 instructions extended by review Q2 (Always Trust for Code
  Signing).
- Attempt 2 (2026-09-22, after Aidan selected Xcode and accepted its license): G1
  still fails, `security find-identity -v -p codesigning` reports 0 identities.
  Agent-accessible checks all pass: `swift build` succeeds with no warnings (Swift
  6.4, macOS 27.2 host, target `.macOS(.v26)`); `./scripts/run.sh` stops at codesign
  with `EchoType Dev: no identity found`, exit 1, before touching any running
  instance. A temporary copy of the script with only the identity swapped for ad-hoc
  (`-`) ran twice: both exits 0, the second run left exactly one `EchoTypeApp`
  process with a new pid, `lsappinfo` reports type `UIElement` (no Dock or Cmd+Tab),
  System Events reports it background-only, `codesign --verify --strict` passes and
  `codesign -dv` reports `Identifier=com.aidanzealley.echotype`. The ad-hoc instance
  and bundle were then removed. No correction was needed. Still unverified by the
  agent: the `EchoType Dev` authority (needs G1), and the visible menu bar icon and
  its Quit item (the agent's harness lacks assistive access to click it).
- Attempt 3 (2026-09-22, E1 answered by Aidan): both gates pass. G1: Aidan created
  `EchoType Dev` as a Self Signed Root Code Signing certificate and set it to Always
  Trust for Code Signing. G2: `./scripts/run.sh` succeeds, the waveform icon appears,
  a second run leaves no duplicate, Quit terminates the app, nothing shows in the
  Dock or Cmd+Tab, and `codesign -dv --verbose=4 .build/EchoType.app` reports
  `Identifier=com.aidanzealley.echotype` and `Authority=EchoType Dev`. The lead
  re-checked on the same machine: `security find-identity -v -p codesigning` lists
  `EchoType Dev` (1 valid identity), `codesign -dv` on the built bundle reports the
  same identifier and authority, and `codesign --verify --strict` passes.
- Lasting decisions: builds use Xcode's toolchain, not the Command Line Tools; the
  `EchoType Dev` certificate must be trusted for Code Signing (see Implementation
  handoff, Decisions).
- Resume condition: both gates report pass. Met.

## Implementation handoff

- Base commit: `2c57765` on `spike/macos-hotkey-paste`.
- Outcome: implemented and accepted. At implementation time it was uncompiled and
  unlaunched because the toolchain and the `EchoType Dev` identity were unavailable;
  both were resolved through E1 and all six criteria passed at G1 and G2.
- Files changed (all new): `Package.swift`, `Sources/EchoTypeApp/App.swift`,
  `Resources/Info.plist`, `scripts/run.sh` (executable), `.gitignore` (remediation,
  lead-approved outside initial ownership).
- Decisions:
  - Toolchain (E1, Aidan): builds use Xcode 27's toolchain, selected with
    `xcode-select -s /Applications/Xcode.app/Contents/Developer`, not the Command
    Line Tools, whose swift-driver is broken on this Mac.
  - Signing identity (E1, Aidan): `EchoType Dev` is a Self Signed Root Code Signing
    certificate whose trust is set to Always Trust for Code Signing, so
    `security find-identity -v -p codesigning` lists it as valid. The specification's
    certificate instructions omit the trust step; recorded as drift in plan.md.
  - Package named `EchoType`, one `executableTarget` `EchoTypeApp`, so
    `CFBundleExecutable` is `EchoTypeApp` and `run.sh` copies `.build/debug/EchoTypeApp`.
  - `CFBundleName` is `EchoType`; the version is a single `CFBundleVersion` `0.1`.
  - `run.sh` rebuilds the bundle from scratch each run (`rm -rf` then copy), so no
    stale files survive. Signing relies on the bundle's Info.plist for the identifier.
  - Relaunch uses `pkill -x EchoTypeApp`, then waits on `pgrep` until the old
    process has exited before `open`. Without the wait, `open` can reactivate the
    dying instance instead of launching the new build (criterion 6). `open` without
    `-n` also means a failed kill can never produce a duplicate.
  - Quit calls `NSApplication.shared.terminate(nil)`. No keyboard shortcut, since no
    criterion needs one.
  - Remediation (review Q1): added a root `.gitignore` containing only `.build/` and
    `.swiftpm/` so build output cannot be staged. The lead approved this one file
    outside the packet's initial ownership.
- Verification:
  - Run: `bash -n scripts/run.sh` passed. `plutil -lint Resources/Info.plist` passed.
    `security find-identity -v -p codesigning` ran and reported `0 valid identities
    found`, confirming G1 is still pending.
  - Not run: `swift build`, `./scripts/run.sh` and `codesign -dv --verbose=4
    .build/EchoType.app`. The active developer dir is the Command Line Tools, whose
    swift-driver is broken (missing `llbuild.framework`), and the Xcode 27 license is
    not accepted, so no Swift compile is possible without sudo or xcode-select
    changes that are Aidan's to make. Signing also needs the G1 identity.
  - Run (remediation): `git check-ignore .build .swiftpm` reports both ignored;
    `git status --short` shows `.gitignore` as the only new untracked entry.
  - Not run: shellcheck and swift-format, neither is installed.
  - Criteria 1 to 6 were unverified at implementation. After the toolchain fix the
    lead verified criterion 1 and, with an ad-hoc signed copy, criteria 4 and 6 and
    the identifier half of 5 (see External validation, attempt 2). G1 and G2 then
    confirmed all six on Aidan's machine (attempt 3).
- Known limitations or external checks: none outstanding. `.macOS(.v26)` with
  tools version 6.2 compiles under Swift 6.4.
- Specification drift: the certificate needs Always Trust for Code Signing, which
  the specification's creation steps omit (see Decisions). Otherwise none. The
  specification's `#if os(Linux)` guard in
  `Package.swift` and `NSMicrophoneUsageDescription` in `Info.plist` are omitted
  because the spike has no Linux-buildable target and no audio; they belong to the
  `EchoTypeCore` merge and audio work respectively.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5), reading only; no
  implementation files edited.
- Verdict: no Required findings. The four files match the packet's scope and
  non-goals, and read as correct against SwiftPM, codesign and LaunchServices
  behaviour. Every acceptance criterion is still unverified because nothing could be
  compiled, signed or launched here (broken Command Line Tools swift-driver, Xcode
  license not accepted, no `EchoType Dev` identity). Those conclusions rest on
  reading the code and must be confirmed at G1/G2.
- Checks run: `bash -n scripts/run.sh` passed; `plutil -lint Resources/Info.plist`
  passed; `git check-ignore .build/x .swiftpm/x` reports neither is ignored (no repo
  or global excludes file). Not run: `swift build`, `run.sh`, `codesign`, shellcheck.
- Evidence per criterion (all unverified by execution):
  1. `swift build`: `// swift-tools-version: 6.2` with `.macOS(.v26)` is valid
     (`.v26` was added in PackageDescription 6.2). A single-file executable target
     with `@main` and no `main.swift` is handled by SwiftPM. `App` is
     `@MainActor`-isolated, so calling `NSApplication.shared.terminate(nil)` from the
     Button action is fine under Swift 6 strict concurrency.
  2. `run.sh`: the `.build/debug` symlink points at the host triple's debug dir, so
     the `cp` path is right. `set -euo pipefail` puts the build and codesign steps
     before the kill, so a failed build or missing identity leaves the running
     instance untouched. Good ordering.
  3. `MenuBarExtra("EchoType", systemImage: "waveform")` uses the default `.menu`
     style, so the Button shows as a menu item and terminates the app.
  4. `LSUIElement` is `<true/>` in the bundle's `Contents/Info.plist`.
  5. With no `--identifier`, codesign takes the identifier from `CFBundleIdentifier`,
     and `--force` replaces the linker's ad-hoc signature. The default designated
     requirement will be `identifier "com.aidanzealley.echotype" and certificate
     leaf = H"…"`, which stays the same across rebuilds, and that is what workstream 2
     relies on.
  6. `pkill -x` matches the process name `EchoTypeApp`. The `pgrep` wait and `open`
     without `-n` stop a second run from reactivating the old instance or launching
     a duplicate.
- Required findings: none.
- Optional observations:
  - O1 (`scripts/run.sh:21-22`): `pgrep`/`pkill` match every user's processes. If a
    second logged-in user (fast user switching) is running `EchoTypeApp`, `pkill`
    fails with EPERM, `|| true` hides the failure, and the `pgrep` loop spins
    forever. Adding `-U "$USER"` to both commands fixes it. This is unlikely on a
    one-user dev Mac, so it does not block.
  - O2 (`Sources/EchoTypeApp/App.swift:5`): the `@main` type shares the module name
    `EchoTypeApp`. That compiles, but it can make module-qualified lookups
    (`EchoTypeApp.Foo`) ambiguous once workstream 2 and later work add types. If
    the lead wants to avoid it, renaming the struct (for example `EchoType`) costs
    nothing now.
  - O3: the spec's architecture lists `Resources/EchoType.entitlements`. The packet
    excludes it and the implementation follows the packet. That is correct for the
    spike (no sandbox, no hardened runtime), and the handoff's drift note could
    mention it next to the omitted `#if os(Linux)` guard and
    `NSMicrophoneUsageDescription`.
- Questions:
  - Q1 (`.gitignore`): `.build/` and `.swiftpm/` are not ignored, so G2 build
    output would show up as untracked and could be staged by the workstream commit.
    The packet's ownership list leaves this out. The lead should decide whether to
    add a two-line `.gitignore` in this commit. Recommended.
  - Q2 (G1 evidence, `plan.md` rather than this code): a Keychain Access
    "Self Signed Root" certificate is untrusted by default.
    `security find-identity -v` lists only valid identities, so the new identity
    may not appear (it shows without `-v`, flagged `CSSMERR_TP_NOT_TRUSTED`) until
    Aidan sets its trust to "Always Trust" for Code Signing. codesign may still sign
    with it, but the G1 evidence as written could report a false fail. Consider
    adding the trust step to the G1 instructions. Unverified here: no identity
    exists to test with.

## Resolution

- Finding dispositions:
  - Q1 accepted: root `.gitignore` with `.build/` and `.swiftpm/`, added in the one
    remediation pass. The only file outside the packet's initial ownership, approved
    by the lead because the workstream commit must not stage build output.
  - Q2 accepted as a gate instruction, not code: the G1 instructions in the plan's
    escalation entry now include setting the certificate to Always Trust for Code
    Signing.
  - O1 rejected: guards against a second logged-in user running the dev build on a
    single-user dev Mac. Hypothetical, and the packet does not ask for it.
  - O2 rejected: nothing in a single-module app needs module-qualified lookups, so
    the rename protects no real case.
  - O3 rejected as drift: the packet explicitly excludes an entitlements file and the
    specification allows none to be needed without sandbox or hardened runtime. The
    spike does not change the specification's eventual layout.
- Simplification/deletion pass: the implementation agent removed a short-version
  string and a Cmd+Q shortcut. Lead reread all five files; nothing further to delete.
- Final verification: `bash -n`, `plutil -lint` and `git check-ignore` pass.
  `swift build` passes with no warnings. G1 and G2 passed on Aidan's machine, and the
  lead re-checked the identity and the bundle signature there (External validation,
  attempt 3). No code changed after closure.
- Terminal decision: accepted. No Required findings, closure passed, both gates
  passed. E1's lasting decisions are in the handoff Decisions and the plan's decision
  and drift log; the entry is removed.

## Closure review

- Reviewer: fresh closure review agent (Claude Opus 5), reading only apart from this
  section. Scope: accepted findings Q1 and Q2, plus the fixes and the
  simplification pass, checked for release-blocking defects.
- Q1 verified fixed: root `.gitignore` contains only `.build/` and `.swiftpm/`;
  `git check-ignore .build/x .swiftpm/x` now reports both ignored (it reported
  neither at independent review); `git status --short` shows no build output.
- Q2 lead-owned, not failed: `plan.md` has no Always Trust step yet (no "trust" match).
  The lead writes it into the escalation entry when G1 blocks. Until then the
  Resolution's "now include" is ahead of the file, and the lead must add the step
  before G1 is handed to Aidan.
- Simplification pass verified: `Info.plist` has only `CFBundleVersion` and no
  short-version string; the Quit button has no keyboard shortcut.
- Fixes rechecked: `bash -n scripts/run.sh` and `plutil -lint Resources/Info.plist`
  pass; `run.sh` is executable; the build and codesign steps still run before the kill.
  The remediation changed no implementation file.
- Verdict: pass. No release-blocking defects. Criteria 1 to 6 stay unverified by
  execution until the toolchain fix, G1 and G2.
- Remaining required findings: none. Open lead action: write the Q2 trust step into
  the plan.md G1 escalation entry.
