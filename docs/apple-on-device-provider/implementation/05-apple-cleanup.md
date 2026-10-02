# Workstream 5: Clean up dictation on the Mac with Foundation Models

Status: not started.

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
