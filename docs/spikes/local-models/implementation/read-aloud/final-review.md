# Local read aloud (slice 3) whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved [spec](../../spec.md). Read the accepted handoffs, but review the combined diff and the
code around it independently.

Audit:

- every slice 3 requirement in the spec's "Provider and candidate selection", "Native
  integration" (read aloud), "Model delivery experiment", "Evaluation" (read aloud, combined
  memory), "Build verification" and "Completion criteria", against the plan's recorded drift;
- the plan's cross-workstream contracts, especially the speech stream contract in both adapters:
  chunks of at most 100 ms at one rate, bounded production while not pulled, first audio before
  the whole passage, and prompt, repeatable cancellation;
- model lifecycle: only selected candidates prepared, loaded-model reuse with fresh request state,
  teardown, MLX buffer limits, and runtime downloaders and Hub fallback never used;
- dependency direction: no candidate, voice or model named outside `Providers/Local/` and the
  bench, and app code that treats Local as any other provider;
- duplicated state, speculative machinery, and comparison machinery that should not become
  permanent;
- test value: focused tests for real risks, no ceremonial ones;
- agreement between the code, `results.md` (including the spike's conclusion), the spec, the
  research and the test harness spec, including every run id `results.md` cites;
- external behaviour still unverified.

Verification:

```bash
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-read-aloud/EchoType.app
codesign --verify --deep --strict .build/local-read-aloud/EchoType.app
```

Do not launch the app, run xAI, or quit or kill Aidan's EchoType processes.

## Initial whole-feature review

- Reviewer: fresh whole-feature reviewer subagent (Claude Code), 2026-10-07.
- Branch, base, and reviewed head: `spike/local-models`, base
  `20afdf511b42f343a206f816778884b8b05a7633`, reviewed head
  `27046c67ab8b832568d4c85ef38fdfe7398aaecb` (plus the uncommitted status lines in this file and
  `plan.md`).
- Verification run: every command passed at the reviewed head, run in one background script, each
  exit 0. `swift test`: core 145, bench 23, app 76 tests, no warnings in project sources.
  `swift build -c release --product EchoTypeApp`: complete (126.6 s).
  `scripts/build-app.sh release .build/local-read-aloud/EchoType.app`: complete; `Contents/Resources`
  holds `AppIcon.icns` and the `FluidAudio`, `mlx-swift_Cmlx`, `swift-crypto_Crypto` and
  `swift-transformers_Hub` bundles; executable SHA-256 `6457585c…4114`.
  `codesign --verify --deep --strict .build/local-read-aloud/EchoType.app`: passes. Nothing failed,
  so no comparison against the starting commit was needed. `.build/voice-check/` was not touched.
- Acceptance-criteria audit:
  - Provider and candidate selection: met. `LocalCandidates.swift` holds `VoiceCandidate` (pinned
    manifests, voices, speed range, limit, loader) and `LocalSelection.build` is
    `parakeet-unified`, `qwen3-4b-2507`, `kokoro`. Only the selected candidate's `LocalModel` is
    built; a nil voice keeps the unavailable service (`LocalModelTests`). No new protocol or
    factory.
  - Native integration (read aloud): met, with approved drift. Kokoro (`KokoroSpeech`) and Qwen
    (`QwenTTSSpeech`) each hand out mono Float32 chunks of at most 100 ms at one rate, start the
    next utterance only when the reader takes the first chunk of the current one, and make a
    pending `next()` throw on `cancel()`, idempotently; both are covered by focused
    `boundedReadAhead` and cancellation tests. Inference is off the main actor (Kokoro's
    `KokoroAneManager` is an actor; stream tasks are unstructured from nonisolated code). Qwen's
    unawaitable cancellation (ET-R3-01), its utterance cap (ET-R4-02) and speed `1...1` are
    recorded drift. Speed control was verified (0.5, 1, 2; `20261007T101858Z-local`,
    `20261007T101904Z-local`, `20261007T101901Z-local`).
  - Model lifecycle: met. `LocalModel` prepares only selected candidates, starts setup only for
    `.missing`, loads once and reuses the weights; each reading gets fresh request state (FluidAudio
    synthesis per utterance; MLX Audio Swift's fresh cache per generation). `Memory.cacheLimit` is
    64 MiB in both MLX loaders. Runtime downloaders are never called: Kokoro reaches the store
    through `linkFolder` links and converts Emma's pinned JSON locally; Qwen loads with
    `fromModelDirectory`, and swift-transformers' `loadConfig(modelFolder:)` reads only local files
    (checked in the pinned checkouts). Teardown is process exit; Qwen's stop-then-quit risk is
    ET-R3-01, still unobserved.
  - Model delivery: met. Both manifests carry repository, full revision, licence and every file's
    size and SHA-256 (sums recomputed: 49 files, 97,489,362 bytes; 7 files, 2,311,984,361 bytes).
    Runtime-written files, Core ML cache and download/load figures are recorded in `results.md`
    Cost. Offline reading passed for both voices (`20261007T104112Z-local`,
    `20261007T104124Z-local`).
  - Evaluation and combined memory: met, with approved drift (no xAI run, style prompt judged in
    the audition, round-trip scoring not built). Every run id `results.md` cites exists under
    `runs/` (58 checked); the 22 slice 3 runs are release builds at `d6295554` with the expected
    command, candidates and voice. Spot-checked against `report.md`: every first-audio, real-time,
    gap, pause, cancellation, preparation and footprint figure in Read aloud, plus the dictation
    comparison; the blind-rating means and check counts recomputed from `ratings.json` match
    (3.71, 2.88, 2.71, 1.50, 1.43; 10, 11, 8, 17, 15 of 21). The capped-reading marks agree with
    the logs (222-step readings in `20261007T101342Z-local`). See F1 for one misread figure.
  - Build verification: met (above); no `build-app.sh` change was needed, and workstream 4 changed
    no source.
  - Completion criteria: met as far as an agent can check. The voice decision covers Heart and
    Emma, the style-prompt trial, cold and warm first audio, gaps and the quality-for-speed
    tradeoff; the spike recommends one fixed set as a proposal, with the build selection unchanged.
    0.6B is labelled as not run, with its condition unmet.
  - Dependency direction: met. No candidate, voice or runtime is named outside
    `Providers/Local/`, the bench and their tests; `Reader`, Settings and the app use `Provider`
    only.
  - Duplication and comparison machinery: proportionate for a spike. `linkFolder` was extracted from
    Parakeet rather than copied; `--candidate`, the candidate lists and both Qwen manifests are
    named for removal in the proposed production scope.
  - Tests: focused on real risks (player queue maths, contract check, listening labels, utterance
    splitting, bounded read-ahead, cancellation, MB progress, manifest pinning). None is ceremonial.
  - Docs: `results.md`, `research.md` and the test harness spec agree with the code and runs,
    except F1 and O1.
  - Unverified external behaviour: Qwen stop-then-quit (ET-R3-01) and the `.build/voice-check/`
    crash-report check; first load after reboot or OS update; the cause of Kokoro's recurring 11 to
    13 s loads; energy; Developer ID notarisation; CI with MLX Audio Swift; the recommended set
    (boosted Unified, Qwen3-4B, Kokoro Heart) loaded together. All are recorded in `plan.md` or
    `results.md`.
- Required findings by owner:
  - `docs/spikes/local-models/results.md` (workstream 5's record):
    - **F1. The pause figure is read as proof that production stays bounded, which it cannot
      show.** `results.md:877` says "A paused reader holds about one second of audio for every
      voice, so production stays bounded", and `:962` says the combinations "kept the pause
      bounded (1.1 s of audio ready after resume)". `speak` counts chunks pulled within 1 s of
      resuming that returned in under 10 ms (`Speak.swift`, `audioAfterResume`), and the modelled
      500 ms player only lets about 1 to 1.5 s be pulled in that second, as workstream 1 recorded
      ("tops out near 1.5 s; more than zero means the stream generated ahead",
      `01-bench-speak.md`, Decisions). Every voice reads 1.1 to 1.3 s, including Apple, which
      generates the whole stream ahead (`20261006T140826Z-apple`, `20261006T141044Z-apple`). So
      the figure shows that audio was ready after the pause, not how much was held. Fix: reword
      both sentences to say so, and rest the bound on the streams' design and their
      `boundedReadAhead` tests, with the flat footprint across the pause as supporting evidence
      (e.g. Kokoro 469 to 469 MiB, Qwen 2475 to 2385 MiB). No rerun needed.
- Optional observations:
  - **O1.** `results.md:1093-1094`, "Integration changes made", lists "Settings falls back to the
    first voice for a stored voice the build does not offer". That behaviour predates the spike
    (`Settings.Reading.validated(for:)`, from `e83f73a` on `main`); workstream 4 changed no source.
    Say the app's existing fallback covered it.
  - **O2.** The `speak` run's `speech` field is decoded by three private types: `RunInfo.Speech`
    (`RunInfo.swift`), `RunSettings.Speech` (`Report.swift`) and `Info.Speech` (`Listening.swift`).
    One `Codable` type would do. Bench-only, small.
  - **O3.** The bench's after-resume measure cannot tell bounded from unbounded production (F1's
    cause), so the spec's "buffering while paused" rests on unit tests and footprint. A stream-side
    count of audio produced during the pause would measure it. Harness follow-up, not this slice.
  - **O4.** `linkFolder` leaves a real `~/.cache/fluidaudio/Models/kokoro` folder alone (as for
    Parakeet's CTC tokenizer), so if another FluidAudio tool created one, Kokoro reads its G2P
    resources and lexicon from there, and FluidAudio's existence-only checks could download a
    missing file into it. Accepted slice 2 pattern; worth revisiting when productionising.
  - **O5.** `QwenTTSSpeech.utterances` builds on `KokoroSpeech.utterances` and undoes its
    100-scalar first cut by rejoining. Fine while both exist; the production scope removes Qwen.
  - **O6.** `plan.md:3` still says "Status: approved; implementation has not started."
- Questions: none.
- Verdict: changes required. One Required documentation correction (F1) in `results.md`; the
  code, tests, builds and signed bundle pass, and no code defect was found.

## Lead triage

- Lead: fresh final-review lead (Claude Code), 2026-10-07, recovering an interrupted lead whose
  only uncommitted work was the Review status lines; no review record existed, so the review ran
  afresh.
- Accepted findings and owners: F1 (Required) and O1 (promoted: the results misstated what slice 3
  delivered; confirmed no Settings or app source changed since the base), both in
  `docs/spikes/local-models/results.md`, fixed by one fresh implementation agent. O6 fixed by the
  lead in `plan.md`, which it owns.
- Rejected findings and reasons: none.
- Deferred optional observations: O2 (one `Codable` type for the run's `speech` field; bench-only
  tidying), O3 (a stream-side measure of audio produced while paused; harness follow-up, recorded
  as drift), O4 (`linkFolder` honouring a pre-existing real FluidAudio cache folder; accepted slice
  2 pattern, revisit when productionising), O5 (Qwen's splitter rejoining Kokoro's first cut;
  removed with Qwen in the proposed production scope).
- Drift requiring user decision: none. The harness spec's "audio generated while paused" is not
  what `speak` measures (O3); recorded in the plan's drift log, as the results no longer rely on
  it.

## Focused closure

- Reviewer: fresh closure reviewer subagent (Claude Code), 2026-10-07.
- Reviewed head: `27046c67ab8b832568d4c85ef38fdfe7398aaecb` plus uncommitted `results.md`
  corrections (and the uncommitted status lines in this file and `plan.md`).
- Finding outcomes:
  - **F1: fixed.** `results.md:877-881` now says the after-resume figure counts only what the
    modelled 500 ms player pulls in the first second, is about one second for every voice
    including Apple, and does not show the bound; the bound rests on the streams running at most
    one utterance ahead (`KokoroSpeechTests.boundedReadAhead`,
    `QwenTTSSpeechTests.boundedReadAhead`) and the flat footprint across the pause. Checked: both
    tests exist in `Tests/EchoTypeCoreTests/` and assert that at most two utterances have started
    after the first chunk is pulled and 1000 yields pass, then all four once drained; the
    wording matches `Speak.swift` and `Report.swift`. Footprint across the pause in the cited paced
    runs' `report.md`: Emma 469 to 469 MiB, Heart 409 to 417, Ryan 2475 to 2385, so flat or falling
    (Heart +8 MiB, under 2%). `results.md:966` now says both combinations "had 1.1 s of audio ready
    in the first second after the pause" with no boundedness claim; both runs
    (`20261007T104327Z-local`, `20261007T104448Z-local`) report 1.1 s.
  - **O1 (promoted): fixed.** `results.md:1097-1098` now credits the voice-candidate fallback to
    Settings' existing behaviour (`Settings.Reading.validated(for:)`, from `e83f73a`, an ancestor of
    the base `20afdf51`).
  - O2 to O5 deferred and O6 left to the lead, as triaged; not re-reviewed.
- Final simplification assessment: the corrections are wording only, replace rather than add
  claims, and introduce no new figure that the runs or tests do not support. Nothing to remove.
- Verification: every command in the packet passed, run in one background script, each exit 0.
  `swift test`: core 145, bench 23, app 76 tests, no warnings in project sources.
  `swift build -c release --product EchoTypeApp`: complete (131.7 s).
  `scripts/build-app.sh release .build/local-read-aloud/EchoType.app`: complete; `Contents/Resources`
  holds `AppIcon.icns` and the `FluidAudio`, `mlx-swift_Cmlx`, `swift-crypto_Crypto` and
  `swift-transformers_Hub` bundles. `codesign --verify --deep --strict
  .build/local-read-aloud/EchoType.app`: passes. `.build/voice-check/` was not touched; the app
  was not launched.
- Remaining blockers: none. External items unverified by an agent are unchanged from the initial
  review and recorded in `plan.md` and `results.md`.
- Verdict: accepted. F1 and O1 are fixed accurately and the fixes introduce no release-blocking
  defect.

## Completion record

- Final verification: all four packet commands passed at closure on the corrected tree (`swift
  test` core 145, bench 23, app 76; release build; `build-app.sh` to
  `.build/local-read-aloud/EchoType.app`; `codesign --verify --deep --strict`). The corrections
  are documentation only.
- External validation pending: as listed in `plan.md`'s whole-feature acceptance: CI with MLX
  Audio Swift, first load after a reboot or OS update, energy, notarisation of nested bundles,
  boosted Unified's 44 s installed load, the Qwen stop-then-quit crash-report check and deletion
  of `.build/voice-check/` once Aidan has quit it, and productionising. Also unmeasured: the cause
  of Kokoro's recurring 11 to 13 s loads and the recommended set loaded together (`results.md`).
- Specification drift: `speak` reports audio ready in the first second after resuming, not the
  harness spec's "audio generated while paused"; bounded production rests on the streams' design,
  their `boundedReadAhead` tests and flat footprint (plan's drift log, 2026-10-07).
