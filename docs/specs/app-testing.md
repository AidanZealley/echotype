# App testing and scripted evaluation

Status: deferred draft, updated 2026-10-11. This follow-up is not approved or implemented.
The [productionization pass](local-models-productionization.md) completed local implementation
and review on 2026-10-11; merge and public release remain separate steps.

## Goal

Reduce Aidan's routine manual testing with three kinds of tooling in the codebase:
unit and integration tests, local end-to-end tests, and scripted evaluations of how
EchoType uses its models. Productionization retires the model bench before merging;
this follow-up starts independently afterwards. Archived code/cases may inform it but
are not a required implementation dependency.

It replaces the broader direction in [Test harness](test-harness.md) once approved.
That earlier document records the historical bench direction, not a requirement to
retain or reconstruct the retired tool.

## Testing tiers

| Tier | Purpose | Execution |
| --- | --- | --- |
| Unit and integration tests | Assert logic, operation lifecycle and failure handling using controlled dependencies | Existing Swift test targets, locally and in CI |
| End-to-end tests | Verify repetitive user flows through a built, running app | Explicit local commands, outside the default CI gate |
| Scripted evaluations | Replay cases through production code and real models to measure the effects of app changes | Explicit local commands, outside the default CI gate |

Use the repository's normal testing tools. Build focused scripts for evaluation rather
than a standalone testing product. A test belongs in the lowest tier that can establish
its required outcome; avoid reproducing the same assertions at every tier.

## Scope and feature selection

Prioritise checks by how often Aidan repeats them, the impact of failure and whether an
automated result is trustworthy. Protect observable behaviour rather than internal call
sequences. New cases should cover a meaningful requirement or a reproduced defect.

Initial coverage is bounded to:

- Dictation start, stop, quick stop, cancellation and a successful subsequent session.
- Cleanup preservation, correction handling and fallback when cleanup fails.
- Reading start, stop, pause and resume, and interruption by dictation.
- Independent Dictation and Read Aloud providers, settings persistence and migration.
- Local installation cancellation, retry, removal and offline use.
- Text insertion and clipboard restoration in a controlled destination.
- MCP speech delivery through the running app.

Preserve valuable existing tests and fill demonstrated gaps. Do not rebuild an existing
test merely to fit the tier names. Before implementation, map these behaviours to existing
coverage and assign the missing checks to a tier.

Model discovery, candidate comparisons, arbitrary runtime adapters, automatic model
downloads, a scenario language, a plugin system, an agent service and natural-language
report generation are outside scope. Subjective voice preference, physical microphone
and audio-device behaviour, first-use permissions and broad destination-app compatibility
remain a short documented manual checklist.

## Unit and integration tests

Keep deterministic tests in the existing Swift test targets and default CI test step.
Use controlled providers, clocks, capture, insertion and playback dependencies to exercise
real operation and coordination code. Use temporary storage for installation tests.

Assert outcomes such as inserted text, no insertion after cancellation, preserved text
after cleanup failure, released resources and a working subsequent operation. Include
independent feature failures: a missing Dictation credential must not block usable Read
Aloud, and a missing speech model must not block usable Dictation.

These tests make no paid requests, download no models, require no desktop permissions and
produce no audible playback. Extend existing injection points only where needed to test
a real behaviour. Keep test-only mechanisms out of release builds.

## Local end-to-end tests

Provide explicit local commands to exercise the signed app and a controlled destination.
Use the app's actual settings, admission, operation, insertion and speech-delivery paths.
A direct call to a provider or operation is an integration test, not an end-to-end test.

Document the build, permissions, installed-model and desktop prerequisites. Validate them
before running and report unmet prerequisites distinctly from a test failure. Use a
dedicated test app identity and data locations so tests cannot alter the normal install's
settings, credentials or model store. Shared read-only model assets may be supplied
explicitly; installation and removal scenarios use isolated owned storage.

Where recorded input is necessary, provide the smallest test-only input mechanism while
retaining the production path downstream. Label any bypassed boundary in the result.
Recording-fed dictation does not establish microphone correctness, and a controlled audio
sink does not establish audible playback. Test-only controls are unavailable in release
builds. Keep separate signed release validation for packaging and resources.

Run scenarios sequentially where they share desktop state. Tear down launched test apps,
cancel work and restore temporary changes on completion or failure. Tell the user that
desktop tests require focus and may use the clipboard before starting them. Never paste
test text into an uncontrolled destination.

Each scenario produces a structured pass, fail or blocked result, with failure evidence
such as captured output, events or screenshots where useful. Default CI does not invoke
this tier. Agents can invoke the same local commands as Aidan.

## Scripted evaluations

Evaluate EchoType's use of a fixed model set. The main initial use case is comparing
cleanup strategies, including lookback length and original versus previously cleaned
input. Model identities and revisions stay fixed across a comparison.

Support two fixture inputs:

- Timed transcript events to isolate cleanup behaviour with transcription held constant.
- Recorded audio to measure transcription and cleanup together, including commit timing.

Feed fixtures through the relevant production operation and cleanup path, capturing the
text that would be inserted. Avoid independently implementing revision scheduling,
lookback or finalisation in the evaluation code. Run real-model evaluations in release
configuration. The app operation can run in-process with explicit capture and insertion
dependencies; desktop automation is not required for these evaluations.

Start with a small reviewed corpus covering explicit corrections, deliberate repetition,
false starts, long utterances, pauses, dictation containing questions or commands, and
silence. A new behaviour can add a new recording or transcript fixture. Run that case
against both baseline and changed code, alongside the new evaluation corpus.

Each case identifies its input, reviewed reference and intended behaviour. For cleanup,
retain the raw transcript and expected cleaned output, with reviewable edit annotations
where needed to distinguish wrong deletions from missed edits. Ambiguous cases are marked
for manual assessment and excluded from automated quality totals. Version fixtures and
references so results remain attributable after edits.

Keep private recordings, transcripts and generated output outside git by default.
Commit synthetic or explicitly approved shareable fixtures only. Provide a documented
way to record a sample and review its reference without requiring the retired bench.

Measure, where applicable:

| Measurement | Meaning |
| --- | --- |
| Final output and text difference | What the app would insert versus the reviewed reference |
| Word error rate | Word insertions, deletions and substitutions, with raw counts and denominator |
| Wrong deletions | Intended words removed by cleanup |
| Missed edits | Reviewed cleanup edits the app did not perform |
| Required-term accuracy | Expected terms retained or transcribed correctly |
| Stop-to-insert time | Elapsed time from stop to captured insertion, excluding actual desktop delivery |
| Revision events | Inputs, outputs, fallback reasons and timing for each cleanup attempt |
| Behaviour checks | Explicit assertions such as silence producing no inserted text |

Define tokenisation, normalisation and edit-counting rules once, with meaningful tests.
Report wording metrics separately from punctuation and case differences. Silence has no
word-error-rate denominator; report unexpected output directly. Do not turn meaning
preservation into an unsupported numerical claim or combine quality and latency into one
overall score.

Provide explicit commands to run selected cases and compare two completed runs. Record
the source revision and dirty state, build configuration, model revisions, relevant settings,
fixture versions and machine conditions. Separate preparation from operation timing.
Label cold and warm samples. Compare like conditions and mark mismatches rather than
silently presenting them as controlled comparisons. Support repeats when variability
matters, without treating repeats as additional distinct cases.

## Output contract

The tooling produces structured data, not narrative reports or inferred explanations.
Use JSON for run metadata, results and comparisons, and JSONL where event traces warrant it.
Define a small versioned schema with stable case ids, named fields, explicit timing units,
raw counts and denominators. Every requested case has an outcome; missing fixtures and
skipped cases remain visible. Missing values are explicit, not fabricated zeroes.

Comparisons contain per-case and aggregate numerical deltas and output differences.
They do not infer causes, recommend code changes or identify subjective winners.
Keep immutable per-run artifacts so comparisons can be recomputed without rerunning models.

Aidan can inspect the files directly. Document their fields and example commands for
extracting tables or individual traces. Agents consume those same files and may generate
separate summaries, plots, reports and suggestions when asked. No agent is required to
execute, score or compare runs. A dashboard or graphical data browser is outside the
initial implementation.

Assertive tests return a failing exit status when an assertion fails. Evaluations return
success when execution and scoring complete, even if quality worsened; the measured
regression belongs in the structured comparison. Execution errors and blocked required
cases return a non-success status with a distinguishable reason. Test failure, quality
change and inability to run must remain separate concepts.

Paid-provider evaluation is explicitly requested, never a default. Commands disclose that
the selected provider sends fixture content externally. Credentials stay out of artifacts.

## Implementation order and historical evidence

1. After productionization has merged, inventory existing tests and select the missing
   behaviour checks. Record which tier will establish each outcome.
2. Extend deterministic tests and their existing CI step. Add local end-to-end commands
   and the smallest required app controls, verifying isolation and cleanup.
3. Add scripted evaluation of cleanup using timed transcripts and recorded audio, with
   structured results and baseline comparisons. Demonstrate it on two code revisions.
4. Review the completed testing changes and remove unused new tooling. If historical bench
   cases are useful, recover reviewed fixtures from git or user-owned artifacts with explicit
   consent for private data migration. Do not restore the old executable, corpus schema or
   compatibility interfaces merely to run the new tests.

Do not wrap or extend the bench as the new evaluation implementation. Derive the new
commands and result schema from this spec. Generic audio helpers already shared by real
tests may remain where justified. Historic source and spike results remain in git;
existing user recordings and run artifacts are not deleted automatically.

Update the old harness spec to historical/superseded status when this work is implemented.
Perform a deletion and simplification pass before completion. Keep only shared helpers
that serve current tests; no compatibility facade for the retired executable is required.

## Acceptance

- Default CI runs deterministic unit and integration tests without models, credentials or
  desktop access. Meaningful existing coverage remains intact.
- Local end-to-end commands establish the selected app flows, distinguish blocked setup
  from failures and leave the normal install untouched.
- Scripted evaluation runs timed transcript and recorded-audio cases through production
  code with real installed models, without desktop interaction or an agent interpreter.
- A baseline-versus-change demonstration records controlled inputs and produces final
  outputs, quality counts, timing and per-case deltas in the documented structured format.
- Incomplete execution cannot produce an apparently complete passing result. Private
  content and credentials follow the storage rules above.
- Aidan and agents can run the same commands, find artifacts and inspect their fields.
  Interpretation is separate from tool output.
- The new tests run without the retired bench or a compatibility facade. Useful fixtures,
  existing user data and consolidated model evidence are preserved as specified. The original
  spike workflows remain recoverable from `2f231b9`, rather than retained in the production tree.
