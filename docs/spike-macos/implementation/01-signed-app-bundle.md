# Workstream 1: Signed app bundle and run script

Status: not started.

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
- Status: `Pending`
- Candidate and instructions: see the External validation gates section of
  [plan.md](plan.md).
- Required evidence: `security find-identity -v -p codesigning` lists `EchoType Dev`;
  the menu bar icon appears; `codesign -dv --verbose=4` reports the expected authority
  and identifier.
- Attempts and lasting decisions: `TBD`
- Resume condition: both gates report pass.

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
