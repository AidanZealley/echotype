# Workstream 5: Clean up dictation on the Mac with Foundation Models

Status: accepted.

## Task packet

### Outcome

The Apple namespace has a cleanup service and its readiness check, not yet registered. Each request runs in a fresh `LanguageModelSession` with the `Reviser` prompt it receives. Readiness reports whether Apple Intelligence can serve the language.

Specification: [Apple provider](../../specs/apple-on-device-provider.md#apple-provider), the Readiness, Cleanup and Tests bullets. Measurements and pitfalls: [research, cleanup](../../research/apple-on-device-provider.md#cleanup).

### Scope

- `revise`:
  - use a fresh session per request, with the request's prompt as instructions, greedy generation and default framework protections,
  - return the model's reply,
  - map context overflow, guardrail and other framework errors to `ProviderError` so `Reviser` preserves the text,
  - honour task cancellation.
- Cleanup readiness from `SystemLanguageModel.default`:
  - unsupported hardware, Apple Intelligence turned off, or an unsupported resolved language → `.unavailable` with a short reason,
  - model not ready → `.waiting` with a short reason,
  - available and supported → `.ready`.
  
  Use workstream 3's language resolution. Use the change signal if the framework offers an observable availability change; otherwise rely on workstream 1's app-active re-check.
- Fixture tests for the availability-to-`ServiceState` mapping and error mapping, using constructed values.
- An opt-in live check, gated by `ECHOTYPE_APPLE_LIVE=1`, that runs a short revision and an oversized final through the real `Reviser` and confirms text is preserved on failure.

Use `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/Cleanup/` as reference. Do not edit or delete it.

### Non-goals

- Prompt, validator, window or budget changes in `Reviser`. Cleanup quality tuning happens through real use after implementation.
- Truncation, chunking or fallback to uncleaned dictation.
- Registering Apple.

### Initial ownership

- New cleanup files in `Sources/EchoTypeCore/Providers/Apple/`
- New Apple cleanup tests in `Tests/EchoTypeCoreTests/`, with live checks under `Tests/EchoTypeCoreTests/Integration/`

### Required seams

- Consumes the readiness types, the Apple namespace, language resolution and the change signal.
- Produces the cleanup service value and an internal cleanup readiness check. Record their names in the handoff.

### Acceptance criteria

- Fixture tests map every availability case and unsupported language to the specified state with a short reason.
- Framework failures surface as `ProviderError`.
- When live checks are enabled, a short revision returns a reply, and an oversized final leaves `Reviser` preserving the original text within its existing budget.
- Existing `ReviserTests` pass unchanged.

### Targeted verification

```bash
swift build
swift test --disable-xctest --filter 'Apple|ReviserTests'
ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup
git diff --check
```

Adjust the live filter to the suite names you create.

## Implementation handoff

- Base commit: `1f176864f300ba96b7550d611595d47669704885`
- Outcome: `Apple.cleanup`, an unregistered `CleanupService` on `LanguageModelSession`, plus the synchronous cleanup readiness check `Apple.Intelligence.check(language:)`. `Apple.changes` also yields when `SystemLanguageModel.default.availability` changes. Fixture tests and opt-in live checks pass.
- Files changed:
  - `Sources/EchoTypeCore/Providers/Apple/AppleCleanup.swift` (new): `Apple.cleanup`, `enum Apple.Intelligence` with `check(language:)`, `state(_:supportsLanguage:)` and `failure(_:)`.
  - `Sources/EchoTypeCore/Providers/Apple/Apple.swift`: the `changes` closure also starts an app-lifetime task iterating `Observations { SystemLanguageModel.default.availability }` and calling `send()`. Imports `FoundationModels`.
  - `Tests/EchoTypeCoreTests/AppleCleanupTests.swift` (new): fixture tests.
  - `Tests/EchoTypeCoreTests/Integration/AppleCleanupLiveTests.swift` (new): live checks gated by `ECHOTYPE_APPLE_LIVE=1`.
- Decisions:
  - Seams for 6:
    ```swift
    extension Apple {
      static let cleanup: CleanupService
      enum Intelligence {
        static func check(language: String) -> ServiceState
      }
    }
    ```
    Workstream 6 composes `cleanup: Apple.Intelligence.check(language: request.language)` into `Provider.apple.readiness`. It is synchronous and starts nothing: the system downloads and loads the model itself, so there is no adapter-owned setup and no installation-request side effect.
  - Readiness mapping, in this order: `.unavailable(.deviceNotEligible)` -> `.unavailable("Apple Intelligence is not supported on this Mac")`; `.unavailable(.appleIntelligenceNotEnabled)` -> `.unavailable("Needs Apple Intelligence")`; language not supported -> `.unavailable("Cleanup does not support this language")`; `.unavailable(.modelNotReady)` -> `.waiting("Preparing Apple Intelligence")`; any future unavailable reason -> `.unavailable("Apple Intelligence is unavailable")`; `.available` -> `.ready`. An unsupported language outranks a model that is still loading, since waiting would never end. Language support is `SystemLanguageModel.supportsLocale(Apple.locale(for:))`, so bare `en` is checked as `en-GB`.
  - `revise`: a fresh `LanguageModelSession(instructions: request.prompt)` per request, `GenerationOptions(samplingMode: .greedy)`, default guardrails, returns `response.content` untrimmed (`Reviser` trims). `request.final` and `credential` are unused; `Reviser` owns the final budget by cancelling.
  - Errors: cancellation is checked before the session, after the reply and on any thrown error, so a cancelled request throws `CancellationError`. Every other error becomes `ProviderError.failed(error.localizedDescription)`, with no per-case mapping: the runtime (macOS 27) and the deployment target (macOS 26) have different error families (`LanguageModelError` vs the deprecated `LanguageModelSession.GenerationError`), and `Reviser` treats all failures alike. Live context overflow surfaces as `failed("The session's transcript exceeded the model's context size.")`.
  - Change signal: `SystemLanguageModel` is `Observable`, so its availability is followed with `Observations`. The first emission is the current value, which sends one harmless change when `Apple.changes` is first created.
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest --filter 'Apple|ReviserTests'`: 55 tests in 10 suites; live and spike suites skip.
  - `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup`: 8 tests in 3 suites (spike skips). English readiness `.ready`; a short revision replies (2.8 s, process-first); a direct oversized request (~9,000 tokens vs 4,096) throws `ProviderError` after 3.4 s; an oversized final through `Reviser` returns the original text in 3.02 s (the attempt is `cancelled` by the 3 s budget before the overflow error arrives, matching the research).
  - `swift test --disable-xctest`: 138 core tests, 71 app tests.
  - `git diff --check` clean, and no trailing whitespace in the new files.
- Known limitations or external checks:
  - Only `.available` was observed live. `deviceNotEligible`, `appleIntelligenceNotEnabled` and `modelNotReady` are covered by fixtures only, and whether the `Observations` stream fires when Apple Intelligence is toggled or its model finishes loading is unobserved; app activation also re-checks readiness. G2 covers "With Apple Intelligence off, Cleanup ... shows its reason".
  - Error wording in `ProviderError.failed` is the framework's; it reaches only `DictationTrace`, never the pill.
  - Cleanup quality is unchanged from the research; tuning is out of scope.
- Specification drift: none.
- Follow-up for O1: `Apple.Intelligence.check(language:)` dropped its unused `model` parameter and reads `SystemLanguageModel.default` directly; fixtures still inject through `state(_:supportsLanguage:)`. The seam signature above is updated. Reverified, all passing: `swift build`; `swift test --disable-xctest --filter 'Apple|ReviserTests'` (55 tests in 10 suites); `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup` (8 tests in 3 suites, oversized final preserved in 3.18 s); `git diff --check` clean.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5.5, Claude Code), against base `1f17686` plus the untracked files.
- Verdict: Accept. Every acceptance criterion is met, the change stays inside `Providers/Apple/` and the new test files, and no Required finding.
  - Readiness mapping (`AppleCleanup.swift:31-48`) matches the specification's Cleanup readiness: hardware, Apple Intelligence off and unsupported language are `.unavailable`, `modelNotReady` is `.waiting`, and an unknown future reason falls to `.unavailable`. Language goes through workstream 3's `Apple.locale(for:)` (`:28`), and the reason strings match `AppleSpeechAssets.swift:43-45` in form. All seven fixture cases pass (`AppleCleanupTests.swift:7-20`).
  - `revise` (`AppleCleanup.swift:9-21`) is the spike's fresh-session, greedy, default-guardrail call (`AppleProviderSpike/Cleanup/SpikeCleanup.swift`) plus error mapping. Non-cancellation errors become `ProviderError.failed`, and cancellation throws `CancellationError`. `Reviser.judge` (`Reviser.swift:139-141`) classifies on `Task.isCancelled` first, so the final budget behaves as before. No truncation or chunking. `Reviser.swift` and `ReviserTests` are untouched.
  - Lifecycle: `check` is synchronous and starts no setup, which is consistent with the conventions learned, since nothing is adapter-owned. The `Observations` task (`Apple.swift:29-31`) lives for the app, like the existing notification observer. Fixture tests never touch `Apple.changes`. Only the live suites do (`AppleTranscriptionLiveTests.swift:21`), so ordinary runs start no observation of `SystemLanguageModel`.
  - Verification rerun by the reviewer, all passing. `swift build --build-tests` after touching the four changed Swift files produced no warnings. `swift test --disable-xctest --filter 'Apple|ReviserTests'` ran 55 tests in 10 suites, with live and spike suites skipped. `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup` ran 8 tests in 3 suites with the spike skipped: ready 0.01 s, short revision 2.39 s, oversized request `ProviderError` 3.40 s, oversized final preserved in 3.20 s. `git diff --check` is clean.
- Required findings: none.
- Optional observations:
  - O1. `Apple.Intelligence.check(language:model:)` takes a `model: SystemLanguageModel = .default` parameter (`AppleCleanup.swift:27`) that nothing passes. Tests inject through `state(_:supportsLanguage:)` instead. Dropping the parameter and reading `SystemLanguageModel.default` directly removes an unused extension point. The handoff seam signature would need the same edit.
  - O2. The `CancellationError` pass-through in `failure(_:)` (`AppleCleanup.swift:53`) and its test assertion (`AppleCleanupTests.swift:30`) only matter when the framework throws `CancellationError` while the task is not cancelled. The catch already rethrows real cancellation (`:18`), and `Reviser` decides cancellation from `Task.isCancelled`, not the error type. Inlining `throw ProviderError.failed(error.localizedDescription)` in the catch would drop the helper and that branch. The remaining fixture error test (`AppleCleanupTests.swift:22-31`) mostly restates the implementation. The live `oversizedRequestFails` (`AppleCleanupLiveTests.swift:33-39`) already protects "framework failures surface as `ProviderError`" against a real error. Non-blocking: the packet asks for a fixture error-mapping test.
  - O3. The live "oversized final" test (`AppleCleanupLiveTests.swift:41-50`) passes because the 3 s budget cancels the attempt before the overflow error arrives, as the handoff notes. It proves preservation within the budget, as the acceptance criterion requires, not the overflow-to-`failed` path through `Reviser`. That path is covered by `oversizedRequestFails` plus the existing `ReviserTests` failure cases, so no change is needed. It is noted only so nobody reads the test as covering both.
- Questions:
  - Q1. Whether the `Observations` stream (`Apple.swift:29-31`) fires when Apple Intelligence is toggled or its model finishes loading is unobserved, as the handoff says. If it does not fire, app-activation re-checks still cover toggling in System Settings, but a model that finishes loading while EchoType stays frontmost would leave Settings on "Preparing Apple Intelligence" until the next activation or operation. The lead may want this added explicitly to G2's checks in workstream 6, rather than relying on the existing "Apple Intelligence off" item.
  - Q2. Ownership: the packet's initial ownership lists only new cleanup files, but `Apple.swift` (an existing file) gained the `FoundationModels` import and the availability observer. This is within plan.md's "`Providers/Apple/`: created by 3, extended by 4 and 5" and is the only place the shared `Changes` is built, so the reviewer considers it in bounds. It is flagged for the lead's confirmation.

## Resolution

- Finding dispositions: O1 promoted to Required as unjustified complexity (an unused injection parameter) and fixed in the one remediation pass; closure confirmed it. O2 accepted as it stands: `failure(_:)` is the seam the packet's fixture error-mapping test needs, and its cancellation branch is harmless. O3 accepted: the overflow-to-`ProviderError` path is covered by `oversizedRequestFails` and the existing `ReviserTests` failure cases. Q1 passed to workstream 6: G2 should confirm Settings leaves "Preparing Apple Intelligence" without an app activation when the model finishes loading, or accept activation as the refresh. Q2 confirmed in bounds: the plan has 4 and 5 extending `Providers/Apple/`, and `Apple.swift` is where `Apple.changes` is built.
- Simplification/deletion pass: O1 removed the only unused seam. The lead found nothing further to remove; the spike folder is unchanged.
- Final verification: lead reran `swift build`, `swift test --disable-xctest --filter 'Apple|ReviserTests'` (55 tests in 10 suites), `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup` (8 tests in 3 suites) and `git diff --check`; all pass.

## Closure review

- Reviewer: fresh closure agent (Claude Opus 5.5, Claude Code), scoped to O1 (promoted to Required by the lead).
- Verdict: Accept. O1 is resolved, and the fix introduces no release-blocking defect.
  - `Apple.Intelligence.check(language:)` (`AppleCleanup.swift:27-31`) no longer takes a `model` parameter. It reads `SystemLanguageModel.default` once into a local and passes its availability and `supportsLocale(Apple.locale(for:))` to `state(_:supportsLanguage:)`, so the mapping and its ordering are unchanged. The fixtures still inject through `state` (`AppleCleanupTests.swift:17-18`). The only caller, `AppleCleanupLiveTests.swift:23`, already used `check(language:)`. The handoff seam signature reads `check(language: String) -> ServiceState`. No `check(language:model:)` reference remains outside the Independent review's own description of O1.
  - Verification rerun by the reviewer, all passing. `swift build --build-tests`, after touching `AppleCleanup.swift`, produced no warnings. `swift test --disable-xctest --filter 'Apple|ReviserTests'` ran 55 tests in 10 suites. `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup` ran 8 tests in 3 suites, with the spike skipped: ready 0.008 s, short revision 1.76 s, oversized request `ProviderError` 3.39 s, oversized final preserved in 3.04 s. `git diff --check` is clean.
- Remaining required findings: none.
