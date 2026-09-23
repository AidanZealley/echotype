# Open items carried out of the macOS spike

Status: open. Written 2026-09-23, after the spike branch `spike/macos-hotkey-paste`
was accepted.

Everything the spike set out to prove passed, so none of these block it. Each item is
a change the spike's evidence suggests to a document or a comment that the spike does
not own, or a question the spike could not answer from its own scope.

Triage this list once the parallel EchoTypeCore workstream is merged. Some items will
already be settled there, and some will have moved. Delete what no longer matters and
act on the rest.

The evidence behind each item lives in
[implementation/plan.md](implementation/plan.md)'s decision and drift log and in
[implementation/final-review.md](implementation/final-review.md). This file is the
short list, not a second record.

## S1 Specification contradicts itself on the pasteboard restore

Needs Aidan's decision. `docs/specs/echotype-v1.md` step 4 restores the previous
pasteboard contents when `changeCount` advanced by exactly one, but the paragraph
below it says the transcript stays on the pasteboard either way. Both cannot hold.

The spike follows numbered step 4, and Aidan confirmed at gate G3 that his earlier
clipboard came back after Opt+D.

Settle this in the specification before build-order step 3 reuses `Inserter`,
otherwise the first reuse silently picks one reading.

## S2 Certificate creation steps omit the trust step

The specification's steps for creating the `EchoType Dev` certificate do not mention
setting Code Signing to Always Trust. Without that, `security find-identity -v` hides
the identity and `scripts/run.sh` fails at signing with no obvious cause. This cost a
round trip during the spike.

Add the trust step to the specification's signing section.

## S3 macOS 27 grants one permission, not two

On macOS 27.2 the event tap and the posted Cmd+V are covered by a single "Device
Control and Data Access" grant, attributed to EchoType itself. The specification still
describes separate Accessibility and Input Monitoring grants.

Two consequences for the specification:

- The permissions section should describe what macOS 27 actually asks for.
- The escape hatch `tccutil reset Accessibility com.aidanzealley.echotype` should
  become `tccutil reset All com.aidanzealley.echotype`. Only `reset All` was verified.
  Whether `reset Accessibility` still clears the macOS 27.2 grant is untested, so do
  not record the recommendation as proven without testing it.

## S4 Hotkey comments name the old permission

`Sources/EchoTypeApp/HotkeyMonitor.swift` comments say "Accessibility not granted" and
"Surfaces the Accessibility prompt". The call really is the Accessibility trust check,
so the comments are right about the API and wrong about what the user sees, which is
the S3 prompt.

Deliberately deferred during final review. A word or two, best done when build-order
step 3 rewrites this code.
