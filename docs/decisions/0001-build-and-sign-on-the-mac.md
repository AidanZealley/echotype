# 0001 Build on the Mac and sign with a self-signed certificate

Status: accepted, 2026-09-22 (macOS spike). Certificate choice superseded by
[0014](0014-sign-with-apple-development.md). Linux development dropped at `47e3fa1`.

## Context

TCC grants are keyed to the app's code signature. With ad hoc signing, every rebuild
looks like a new app and macOS asks for permissions again. The spike existed to prove
that a stable signature keeps grants across rebuilds.

## Decision

- Sign every build with the self-signed code signing certificate named `EchoType Dev`.
  Its Code Signing trust was set to Always Trust so `security find-identity -v`
  would list it. This certificate choice was replaced by [0014](0014-sign-with-apple-development.md).
- `scripts/run.sh` is the only build, sign and launch path.
- The bundle identifier in `Resources/Info.plist` never changes. TCC grants, the
  Keychain item and `UserDefaults` all key off it.
- Build with Xcode's toolchain (`xcode-select` pointed at Xcode.app). The Command Line
  Tools swift-driver was broken on the development Mac.

## Consequences

- Grants survived rebuilds and relaunches, which confirmed the spike's main criterion.
- On macOS 27.2 the event tap and the posted Cmd+V need one "Device Control and Data
  Access" grant, not separate Accessibility and Input Monitoring grants. The API check
  is still `AXIsProcessTrusted`.
- To reset permissions, use `tccutil reset All` with the bundle identifier from
  `Resources/Info.plist`. That reset was verified; whether a narrower reset clears
  the macOS 27 grant is untested.
