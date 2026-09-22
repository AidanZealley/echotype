# EchoType macOS spike implementation plan

Status: approved; implementation in progress.

## Orchestration record

- Runs on: Aidan's Mac. Not the remote Linux machine.
- Integration branch: `spike/macos-hotkey-paste`
- Starting commit: `2c57765`
- Review command: `lead subagents`
- Specification approved at commit: `bbb5f41`
- Started: `2026-09-22`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Signed app bundle and run script](01-signed-app-bundle.md) | Approved spec | Accepted |
| 2 | [Hotkey tap and paste](02-hotkey-and-paste.md) | Workstream 1 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-2 | Not started |

## Why these boundaries

Workstream 1 produces a signed, launchable menu bar app and the script that rebuilds
it. Its acceptance depends on the build and signing toolchain working, which is
independently useful and independently judgeable. Nothing in it is a stub for
workstream 2 to replace.

Workstream 2 adds the event tap and the paste, and its acceptance depends on TCC
behaviour. That is a different kind of evidence from a different gate, and the two
groups of criteria could each be accepted on their own.

Splitting also means a signing problem is diagnosed before a tap problem can confuse
it.

## Cross-workstream contracts

Frozen by workstream 1 and relied on by workstream 2:

- Bundle identifier is `com.aidanzealley.echotype`. It does not change after
  workstream 1 commits. TCC grants, the Keychain item and `UserDefaults` all key off
  it, so changing it resets every permission the spike is trying to measure.
- `scripts/run.sh` is the only way the app is built, signed and launched. Workstream 2
  adds no second path.
- The signing identity is the self-signed certificate named `EchoType Dev`.
- `Package.swift` declares one executable target and a macOS 26 platform.

## Ownership handoffs

Workstream 1 creates and owns `Package.swift`, `Resources/Info.plist`,
`scripts/run.sh` and `Sources/EchoTypeApp/`. Workstream 2 inherits
`Sources/EchoTypeApp/` and may add files there. It may change `Resources/Info.plist`
only if a TCC requirement demands it, and must record that as drift.

## Whole-feature acceptance

Final review begins only after both workstreams are accepted, which means both gates
passed on Aidan's machine.

The four spike success criteria, in the specification's order of importance:

1. Opt+D in TextEdit pastes the literal string.
2. No stray `d` character appears, confirming the tap consumes the keydown.
3. After `./scripts/run.sh` rebuilds and relaunches, Opt+D still works with no new
   permission prompt.
4. Quit and relaunch, still works.

Criterion 3 is the reason the spike exists.

## External validation gates

| Gate | Owning workstream | Placement | Status |
|---|---|---|---|
| G1 Self-signed certificate exists | 1 | Before implementation can be verified | Passed |
| G2 App builds, signs and launches | 1 | After closure, before acceptance | Passed |
| G3 TCC grants and the four criteria | 2 | After closure, before acceptance | Passed |

G1 candidate and instructions: Aidan creates a code signing certificate in Keychain
Access via Certificate Assistant, Create a Certificate, identity type Self Signed
Root, certificate type Code Signing, named `EchoType Dev`. Required evidence:
`security find-identity -v -p codesigning` lists it. Resume condition: the identity
is present, so `scripts/run.sh` can sign.

G2 candidate and instructions: Aidan runs `./scripts/run.sh`. Required evidence: a
waveform icon appears in the menu bar, and `codesign -dv --verbose=4` on the built
bundle reports the `EchoType Dev` identity and the expected bundle identifier. Resume
condition: both hold.

G3 candidate and instructions: Aidan runs `./scripts/run.sh`, grants Accessibility and
Input Monitoring when prompted, then works through the four criteria above with
TextEdit focused. Required evidence: a plain statement of pass or fail for each of the
four, and for criterion 3 whether any permission prompt reappeared. Resume condition:
all four pass. macOS may ask only for Accessibility and never for Input Monitoring,
because an active keyboard tap is covered by the Accessibility grant; an absent Input
Monitoring prompt is expected and is not a failure.

If criterion 3 fails, the lead does not attempt to redesign the signing approach on
its own. That outcome changes the specification's development workflow, so it is an
escalation.

## Escalations

None open.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-22 | Drift: the `EchoType Dev` certificate must also be set to Always Trust for Code Signing; the specification's creation steps omit this | Untrusted, `security find-identity -v` hides it; G1 passed with the trust step | Aidan (E1) | 1, 2 |
| 2026-09-22 | Decision: build on the Mac with Xcode's toolchain (`xcode-select` pointed at Xcode.app), not the Command Line Tools | The Command Line Tools swift-driver is broken on Aidan's Mac | Aidan (E1) | 1, 2 |
| 2026-09-22 | Drift: on macOS 27.2 the event tap and posted Cmd+V need one "Device Control and Data Access" grant, not separate Accessibility and Input Monitoring grants; the spec's escape hatch `tccutil reset Accessibility` should become `tccutil reset All com.aidanzealley.echotype` | G3 clean revalidation: after a full TCC reset, one prompt attributed to EchoType; the grant survived a rebuild (criterion 3 passed) | Aidan (E2) | 2, Final |
