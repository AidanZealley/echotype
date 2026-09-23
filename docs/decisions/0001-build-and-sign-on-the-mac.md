# 0001 Build on the Mac and sign with a self-signed certificate

Status: accepted, 2026-09-22 (macOS spike). Linux development dropped at `47e3fa1`.

## Context

TCC grants are keyed to the app's code signature. With ad hoc signing, every rebuild
looks like a new app and macOS asks for permissions again. The spike existed to prove
that a stable signature keeps grants across rebuilds.

## Decision

- Sign every build with a self-signed code signing certificate named `EchoType Dev`.
  Its Code Signing trust must be set to Always Trust. Without that step,
  `security find-identity -v` hides the identity.
- `scripts/run.sh` is the only build, sign and launch path.
- The bundle identifier `com.aidanzealley.echotype` never changes. TCC grants, the
  Keychain item and `UserDefaults` all key off it.
- Build with Xcode's toolchain (`xcode-select` pointed at Xcode.app). The Command Line
  Tools swift-driver was broken on Aidan's Mac.

## Consequences

- Grants survived rebuilds and relaunches, which confirmed the spike's main criterion.
- On macOS 27.2 the event tap and the posted Cmd+V need one "Device Control and Data
  Access" grant, not separate Accessibility and Input Monitoring grants. The API check
  is still `AXIsProcessTrusted`.
- To reset permissions, use `tccutil reset All com.aidanzealley.echotype`. That is the
  verified command. Whether `reset Accessibility` clears the 27.2 grant is untested.
