# Workstream 2: Kokoro read aloud

Status: accepted.

## Task packet

### Outcome

The local provider reads aloud with Kokoro-82M v1.0 through FluidAudio's Core ML pipeline, using
Emma and Heart. Its pinned files come from the model store. It streams bounded, short chunks as
the reader pulls them, honours speed and cancellation, and works offline. The build's selection
names Kokoro, making Unified, Qwen3 and Kokoro the reference combination. The bench measures it
with `--candidate voice=kokoro`.

### Scope

- **Runtime.** Use FluidAudio's `KokoroAne` pipeline at the pinned revision (`0b1f462`), loaded
  from the store's directories through its `directory` or `modelStore` parameters. Move the pin
  only if Kokoro needs it, and then rerun a short transcription pass to show Unified still works.
  Never call its resource downloader.
- **Manifests.** Pin the ANE English models, vocabulary, the English G2P resources the pipeline
  needs, and the `bf_emma` and `af_heart` voice packs, with upstream licences and voice terms. Find
  the exact file list by reading the pipeline's loader, not the downloader's defaults.
  - FluidAudio converts JSON voice packs to `.bin` on first use. Pin the JSON, let it convert into
    the store's directory, and record that as a runtime-created file (see conventions learned).
  - If the G2P resources live in another repository, they get their own manifest.
  - A licence conflict between a conversion and its upstream is recorded, not a stop, as slice 2
    did.
- **Voice candidate shape** in `LocalCandidates.swift`, beside the transcription and cleanup
  shapes: the name, the manifests, the voices, the speed range, the character limit and a loader.
  `LocalSelection` gains `voice`. `LocalSelection.build` names `kokoro`. `LocalProvider` builds
  `VoiceService` and voice readiness from the selected candidate through `LocalModel`, as the
  other services do. With no voice selected it keeps today's unavailable read aloud.
- **Adapter.** A `SpeechStream` that meets the plan's speech stream contract:
  - split text into short utterances at sentence boundaries, with a bound for long sentences;
  - synthesise at most one utterance ahead of what has been pulled;
  - slice audio into chunks of at most 100 ms at Kokoro's fixed rate;
  - honour the request's speed with Kokoro's native speed control;
  - on cancel, end the pending `next()` and stop before the next synthesis step;
  - run inference off the main actor, reusing the loaded models with fresh request state.
- **Utterance bound.** Choose the first utterance's length for fast first audio without losing
  sentence context. Kokoro exposes its phonemes. Compare the phonemes the bounded utterances give
  for `reading-demo-pronunciation` and `reading-past-tense-read` with the phonemes of each whole
  passage. Choose a bound that changes neither "read" nor "demos". Record the bound, the first
  audio it gives, and whether Kokoro's phonemes already reproduce the demo mistakes ("red",
  "dee-moss"). Do not add lexicon entries or word substitutions to fix them.
- **Voices and limits.** Emma first (UK, the default), then Heart. Use Kokoro's supported speed
  range, narrowed if quality breaks down at its ends, and a character limit at least as large as
  any reading sample's. Record both.
- **Bench.** `--candidate voice=kokoro` and the usage text. `speak --provider local` prepares the
  voice alone unless other services are named, per the plan's bench arguments contract.
- Tests only where they guard a real risk, such as utterance splitting and the bound on how far
  synthesis runs ahead.

### Non-goals

- Qwen3-TTS, other Kokoro voices, a custom lexicon or pronunciation fixes.
- App or Settings changes; the app receives the voice through `Provider` as it does now.
- The evaluation's runs and results.

### Initial ownership

- `Sources/EchoTypeCore/Providers/Local/` (new Kokoro files, `LocalCandidates.swift`,
  `LocalProvider.swift`), `Package.swift` and `Package.resolved` if the pin moves.
- `Sources/EchoTypeBench/RunOptions.swift`, `main.swift` usage text, and voice-specific fixes to
  `speak` if a local voice exposes a defect in it.
- `Tests/EchoTypeCoreTests/` and `Tests/EchoTypeBenchTests/` for the focused tests above.

### Required seams

- Consumes the model store, `LocalModel` and the candidate shapes as slices 1 and 2 built them
  ([transcription/01-parakeet-unified.md](../transcription/01-parakeet-unified.md) handoff), and
  workstream 1's `speak` command.
- Produces the voice candidate shape and `LocalSelection.voice` that workstream 3 extends. Name
  the shape, the voice ids and the runtime-created files in the handoff.

### Acceptance criteria

1. `speak --provider local --candidate voice=kokoro` downloads the pinned files on first use,
   reports readiness progress, and reads all eight passages with Emma in paced mode with no
   contract violations. The pause and cancellation trials pass. Repeat with `--voice af_heart` on
   two passages.
2. A `--fast` run with network access denied passes
   (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on the built binary) after the
   files are installed.
3. The speed range's ends audibly change duration: a `--fast` run of `reading-ordinary-prose` at
   each end gives audio durations that differ in the expected direction.
4. The handoff records the manifests with licences, the runtime-created files, the utterance
   bound with its phoneme comparison, and the speed range.
5. `LocalSelection.build` is Unified, Qwen3 and Kokoro. A provider with no voice selected still
   reports read aloud unavailable.
6. If the FluidAudio pin moved, a paced `transcribe --provider local dictation-short-reply`
   passes.
7. `swift test` and `swift build -c release --product EchoTypeApp` pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
swift run EchoTypeBench speak --provider local --candidate voice=kokoro
swift run EchoTypeBench speak --provider local --candidate voice=kokoro --voice af_heart reading-ordinary-prose reading-demo-pronunciation
```

For the speed check, run `speak ... --fast reading-ordinary-prose` once with `--speed` at each
end of the range you set. For the offline run, run
`.build/debug/EchoTypeBench speak --provider local --candidate voice=kokoro --fast` under the
`sandbox-exec` profile above. Then `report` each new run.

## Implementation handoff

- Base commit: `b442628`
- Outcome: Local reads aloud with Kokoro-82M through FluidAudio's `KokoroAneManager`, loaded only
  from the store, with Emma (`bf_emma`, default) and Heart (`af_heart`). `LocalSelection.build`
  is `parakeet-unified`, `qwen3-4b-2507`, `kokoro`. Every acceptance criterion is met on debug
  builds; the FluidAudio pin did not move (criterion 6 does not apply).
- Files changed:
  - New in `Sources/EchoTypeCore/Providers/Local/`: `KokoroManifests.swift`, `KokoroModel.swift`
    (links, voice-pack conversion, load and warm, `speak`), `KokoroSpeech.swift` (the
    `SpeechStream` and the pure utterance splitter).
  - `LocalCandidates.swift`: `LocalSelection.voice`, `VoiceCandidate`, `LocalCandidates.kokoro`
    and `.voice`, `Provider.local(_:)` resolves `voice`. `LocalProvider.swift`:
    `make(transcription:cleanup:voice:)`; voice readiness and changes come from a `LocalModel`
    ("Loading the voice model"); with no voice the old unavailable service remains (its voice is
    now named "Not available", readiness says "No voice model is selected.").
  - `LocalModel.swift` gains the free function `linkFolder(at:to:)`, extracted unchanged from
    `ParakeetModel.linkTokenizer`, which now calls it.
  - Bench: `RunOptions.swift` (`--candidate voice=`; `LocalService.candidates` deleted, since every
    service is now a candidate), `main.swift` usage, `Speak.swift` cancellation trial (see
    Decisions).
  - Tests: new `KokoroSpeechTests.swift` (splitting, read-ahead bound, cancel while synthesising);
    `LocalModelTests.swift` checks the voice manifest and that no voice selected reports read aloud
    unavailable.
- Interface for workstream 3: a voice candidate is one `VoiceCandidate` (`name`, `manifests` in
  loader order, `voices` with the default first, `speedRange`, `maximumCharacters`,
  `load: ([URL]) async throws -> Speak` where `Speak` is `VoiceService.speak`'s signature). Append
  it to `LocalCandidates.voice`; the provider, readiness and the bench's `--candidate voice=<name>`
  need nothing else. Kokoro's voice ids are `bf_emma` and `af_heart`.
- Manifests, licences and runtime-created files:
  - `KokoroManifests.english`: `FluidInference/kokoro-82m-coreml` at
    `006395f65025af251858b1ab0a7178a6a1e73f9f`, 49 files, 97,489,362 bytes, laid out as in the
    repository: `ANE/` (the seven bundles FluidAudio's `KokoroAneStage.bundleName` names, including
    `KokoroProsody_v2`, `KokoroNoise_v2`, `KokoroTail_v2`, file by file, plus `vocab.json` and
    `af_heart.bin`), `voices/bf_emma.json`, and the English G2P resources at the root
    (`G2PEncoder.mlmodelc`, `G2PDecoder.mlmodelc`, `g2p_vocab.json`, `us_lexicon_cache.json`). The
    G2P resources are in the same repository, so there is one manifest. Sizes and hashes come from
    downloading each file at the revision and checking it against the LFS hash where there is
    one. All seven `model.mil` carry `[FlexibleShapeInformation =`, so FluidAudio's cache
    migration (which would download) never triggers.
  - Licence Apache-2.0: the conversion's card, `ANE/LICENSE` and upstream `hexgrad/Kokoro-82M`
    (weights and voice packs) agree. The BART G2P model's own upstream is not named anywhere in
    FluidAudio or the card; recorded under the repository's Apache-2.0. No conflict found.
  - Runtime-created, all written on first load and then left alone:
    `<model dir>/ANE/bf_emma.bin` (522,240 bytes, converted from the pinned JSON with FluidAudio's
    `KokoroAneVoicePack.load(fromJSON:)`, SHA-256 `669fe064…3b73` here); a symlink
    `<model dir>/kokoro-82m-coreml` to the model directory itself, because FluidAudio reads the
    chain from `<directory>/kokoro-82m-coreml/ANE`; and a symlink
    `~/.cache/fluidaudio/Models/kokoro` to the model directory, because `G2PModel.shared` and the
    lexicon loader hard-code that folder. Both links follow the Parakeet rule (written only when
    missing or stale, never over a real folder). The model directory is 94 MB on disk.
- Utterance bound, phoneme comparison and speed range:
  - Utterances are one sentence each; a sentence over the limit is cut at the last `,;:` followed
    by a space within it, else the last space. The first utterance's limit is 100 Unicode scalars,
    later ones 250 (inside the 510-phoneme input and, at 0.5x, the 2000-frame output).
  - Phonemes (a scratch test calling `KokoroAneManager.phonemes(for:)`, since deleted): for
    `reading-demo-pronunciation` and `reading-past-tense-read` the joined phonemes of the bounded
    utterances equal the whole passage's at first limits 30, 40, 60 and 100. FluidAudio's English
    frontend resolves each word alone (lexicon, then BART), so no word boundary cut can change a
    word. Kokoro already reproduces one demo mistake and makes another: "demos" is `dˈimˌɑs`
    ("dee-moss"); "read" is `ɹˈid` everywhere, right in the demo passage ("terms you commonly
    read") but wrong for the past tense ("Yesterday I read the report"). No lexicon changes made.
  - Why 100, not 60: at 60 (experiment run `20261005T094314Z-local`, `--fast --repeat 3`, made with
    the constant at 60 and not cited for the final code) warm first audio p95 fell from 581 to
    344 ms, but cutting first sentences mid-clause added audio (`reading-past-tense-read` 4.3 s to
    5.6 s, `reading-demo-pronunciation` 12.8 s to 13.6 s), a pause where the sentence was split. At
    100 short passages are already well under the target (below), and only
    `reading-numbers-abbreviations`, whose 87-character first sentence normalises to much longer
    speech, exceeds 500 ms (606 ms paced).
  - First audio with 100 (final code, debug, Emma, paced `20261005T100655Z-local`): warm p50 256 /
    p95 606 ms, cold 364 ms; short passages warm p50 163 / p95 252 ms against the 500 ms target.
  - Speed range 0.5...2, the range of Kokoro's own demo (`hexgrad/Kokoro-TTS` slider). Not
    narrowed: no agent can judge quality by ear, so Aidan should listen at the ends in workstream 4.
    Character limit 60,000, as Apple and xAI, since text is synthesised only as it is pulled.
- Decisions:
  - Emma's pack is converted by our loader, not by FluidAudio: `ensureVoicePack` fetches the JSON
    over the network itself and never reads a local one. The loader converts any voice whose
    `ANE/<id>.bin` is missing, with FluidAudio's converter.
  - `KokoroModel.speak` maps a voice id it does not offer to Emma, because FluidAudio would try to
    download an unknown voice. Settings already falls back the same way.
  - The stream synthesises each utterance whole on the shared `KokoroAneManager` actor, so
    inference is off the main actor and loaded weights are reused; each call is independent. The
    next utterance starts when the reader takes the current one's first chunk. `cancel()` ends a
    pending `next()` at once, clears the stream's pending utterances so no further synthesis
    starts, and cancels the in-flight task. FluidAudio checks cancellation only between phoneme
    chunks of an over-long input, which our utterances never are, so the current call (at most
    about 0.6 s here) runs to its end.
  - `speak`'s cancellation trial now pulls on without pacing after its 2 s until a `next()` is still
    waiting after 50 ms, then cancels it. Before, a stream that keeps an utterance ready (every
    local voice) answered at once and the trial was never pending (`20261005T093727Z-local`); now
    it is (`20261005T100655Z-local`, pending after 10.9 s of audio, 0 ms). A stream that ends or
    throws first is recorded as not pending; a throw is a contract violation. Chunks pulled while
    draining are contract-checked. Apple's result is unchanged (not pending, 0 violations), but it
    now drains the whole passage first. This departs from the harness spec's "cancels after about
    2 seconds of audio with a `next()` pending" (also `01-bench-speak.md`): see Specification
    drift.
- Verification: all passed.
  - `swift build`; `swift test` (core 143, app 76, bench 23); `swift build -c release --product
    EchoTypeApp`.
  - Final code (all `report`ed, debug builds):
    - `20261005T100655Z-local`, first download and paced Emma run on the final source, with the
      installed Kokoro directory and the cache link moved aside first: preparation 43.0 s
      (downloading 31.7 s, then "Loading the voice model" 11.3 s); Emma's `bf_emma.bin` converted
      and both links recreated; all 8 passages, 0 violations, 0 gaps; pause in
      `reading-long-selection` 1.2 s after resume, footprint 651 to 651 MiB across it;
      cancellation trial pending, 0 ms, 0 violations; footprint peak 856 MiB, ready 502 MiB.
    - `20261005T130632Z-local`: paced, Heart, `reading-ordinary-prose` and
      `reading-demo-pronunciation`, 0 violations, 0 gaps; its trial was not pending (the
      two-sentence passage was all synthesised by then, 12.8 s drained).
    - `20261005T095204Z-local` (`--fast --speed 0.5`) 19.4 s of audio and `20261005T095208Z-local`
      (`--speed 2`) 5.2 s, against 9.7 s at 1x in `20261005T100655Z-local`.
    - `20261005T094854Z-local`: `--fast`, all 8, under the `sandbox-exec` deny-network profile on
      `.build/debug/EchoTypeBench`, 0 violations; warm real-time factor p50 0.06.
    - These three `--fast` runs predate only the remediation's edit to the cancellation trial,
      which `--fast` never runs.
- Known limitations:
  - A real folder at `~/.cache/fluidaudio/Models/kokoro`, from another FluidAudio tool, is left
    alone, and FluidAudio then reads its G2P files unverified (and would fetch missing ones into
    it), as with Parakeet's tokenizer link.
  - Conversely, another FluidAudio tool on this Mac now writes into the store's Kokoro directory
    through that link (for example other languages' lexicons or `MultilingualG2P*`). FluidAudio
    checks only that files exist, so pinned files are never overwritten; Parakeet's link has the
    same exposure.
  - FluidAudio's English frontend is the Misaki US lexicon with context-free words, so heteronyms
    and British pronunciations are not chosen by context or voice.
  - Kokoro inserts a short silence at each utterance's ends; prosody across joins is for Aidan's
    ear in workstream 5.
  - On macOS 27 FluidAudio defaults the noise and tail stages to the CPU (`aneTailCpu`) because of a
    Core ML GPU abort on the 27 line; it reports no macOS 27 crash, but warns that route crashed
    in long iOS 27 sessions.
  - Figures are debug builds; first model load after a rebuild recompiles for the Neural Engine
    (11.5 s in `20261005T094854Z-local`, 2.7 s after).
- Specification drift:
  - The cancellation trial no longer cancels after about 2 seconds of audio, as
    `docs/specs/test-harness.md` and `01-bench-speak.md` say. It drains unpaced after 2 s until a
    `next()` waits, because a stream that stays one utterance ahead never has a `next()` pending at
    2 s of paced audio. Kokoro cancels after 10.9 s of audio; a short passage or Apple's drains
    whole and is not pending.
  - The packet's "let it convert into the store's directory" is done by our loader with
    FluidAudio's converter, for the reason under Decisions.

## Independent review

- Reviewer: fresh independent review agent (Claude Code), on the uncommitted diff over `b442628`.
- Verdict: Changes required: one Required finding, fixable in the handoff alone. No code defect
  found. Criteria 2, 3, 4, 5 and 7 are met; criterion 6 does not apply (pin unmoved, `0b1f4628`
  checked out); criterion 1 is met apart from Q1.
  - Checks run here: `swift build`, `swift test` (core 143, bench 23, app 76, all passed) and
    `swift build -c release --product EchoTypeApp` (passed). Also one Apple paced run,
    `20261005T095956Z-apple` (`speak --provider apple reading-long-selection`, made on the final
    source), for the cancellation trial's Apple behaviour. The Kokoro runs the handoff cites
    were read, not repeated: their `report.md` figures match the handoff. Their start times
    (`094854Z`, `094912Z`, `095138Z`, `095204Z`, `095208Z`) are after the last source edit, which
    was `KokoroSpeech.swift` at 09:45:16Z.
- Required findings:
  - R1. The cancellation trial no longer cancels "after about 2 seconds of audio", and the
    handoff says it does without recording drift. `docs/specs/test-harness.md` (lines 130-131) and
    `01-bench-speak.md` (line 33) both say "about 2 seconds". The new trial drains unpaced until a
    pull waits: `20261005T094912Z-local` cancels after 10.9 s of audio. `20261005T095138Z-local`
    drains all 12.8 s of the two-sentence passage, so its trial is never pending. The change itself
    is sound: a stream that stays one utterance ahead can never have a `next()` pending at 2 s of
    paced audio, so the wording cannot be met. The README says such a conflict is drift: record it,
    do not resolve it silently. Fix: in the handoff, change the Decisions bullet ("The harness
    spec's wording ... still holds") and "Specification drift: none" to record this drift, so the
    lead can log it. No code change is needed.
- Optional observations:
  - O1. The drain loop pulls with `try? await stream.next()` (`Speak.swift`, the drain `pull`
    task), so a stream that throws after 2 s is recorded as ended and not pending, with no
    violation. The main pass still records failures, so the risk is small. Using `check.threw`
    there would keep the trial honest.
  - O2. The trial's ending could be simpler. `wasPending`'s nested `map`s and `cancelledAt!` could
    become one `if let cancelledAt` branch. That is cosmetic.
  - O3. The handoff's "FluidAudio checks cancellation before each synthesis" overstates it.
    `KokoroAneManager.synthesizeDetailed` calls `Task.checkCancellation()` only between phoneme
    chunks of an over-long input. What stops the next utterance is `KokoroSpeech.cancel()` clearing
    `pending`. The behaviour is correct, so only the sentence needs to change.
  - O4. Another FluidAudio tool on this Mac would now write into the verified store directory
    through `~/.cache/fluidaudio/Models/kokoro`, which is the reverse of the recorded "real folder"
    case. Its French or Spanish lexicons and `MultilingualG2P*` would land there. FluidAudio checks
    existence only, so pinned files would never be overwritten. This is the same exposure as
    Parakeet's link; it may be worth one line under Known limitations.
  - O5. For workstream 4: with `LocalSelection.build` naming `kokoro`, every Local readiness check
    in the app starts Kokoro's download and load (ready footprint about 410-440 MiB in the bench),
    even if the user never reads aloud. This matches the contract and the other services.
- Questions:
  - Q1 (criterion 1's first-download evidence). The store, manifest and readiness code it
    exercises predate `20261005T093727Z-local`, which started at 09:36:38Z. Their file times are
    `KokoroManifests` 09:32:50Z, `LocalModel` 09:33:47Z, `LocalCandidates` 09:34:30Z and
    `LocalProvider` 09:34:39Z, and `ModelStore` is unchanged in git. `KokoroModel.swift` (load,
    links, conversion) was edited at 09:44:55Z, after that run. So creating both links and
    converting Emma's pack from scratch has not run on the final source. Every later run found
    them already present. Repeating the run would not conflict with EchoType:
    - The running app (`/Applications/EchoType.app`, binary dated 4 Oct 21:31, plus its `--mcp`
      process) contains FluidAudio's own Kokoro strings but not this candidate's directory name
      `kokoro-82m-ane-en`. Its selection has no voice.
    - The store keeps each manifest in its own directory and `Incomplete/<name>`, so moving the
      Kokoro directory aside touches nothing that EchoType reads.
    - The README's escalation rule is for steps that need the store to themselves, and this one
      does not.

    I recommend the lead repeat it (about 50 s of download plus a five-minute paced pass) rather
    than accept older evidence or escalate.
- Evidence the lead asked for:
  - (a) The self-referential link cannot cause a loop or a wrong verification:
    - `ModelStore` never walks a directory. `state(of:)` checks only that the installed directory
      exists. Files are verified only while in `Incomplete/`, before the rename. The link is
      written later by `KokoroModel.load`.
    - No code in `Sources/` enumerates directories or sums disk size.
    - FluidAudio reaches files only by fixed paths through the link. These are `ensureModels`'
      existence check, `loadIfNeeded`'s seven bundles, `vocab.json`, the voice packs and the cache
      migration's named `model.mil` files. No enumerator exists anywhere in FluidAudio's TTS code.
    - `du -sh` gives 94M because it does not follow links. Spotlight and Time Machine do not follow
      them either. Only a tool run with `-L` (`find -L`, `du -L`) would report a loop.
    - The link is absolute. If the store moves, `linkFolder` sees it as stale and rewrites it on
      the next load. A set-aside copy keeps a link to the new directory, which does no harm.
  - (b) In normal use FluidAudio fetches nothing:
    - `ensureG2PAssets` finds all three G2P files through `~/.cache/fluidaudio/Models/kokoro`, and
      `ensureEnglishLexicon` finds `us_lexicon_cache.json`.
    - Both voice packs exist before `initialize(preloadVoices:)`, and `speak` maps unknown voices
      to Emma.
    - The English variant never calls the French, Spanish, Mandarin or Japanese fetchers.
    - A fetch happens only if that path is a real folder, which is recorded, or if a store file is
      missing, which an installed directory rules out unless someone tampers with it.
    - The deny-network run `20261005T094854Z-local` confirms this.
  - (c) The trial still holds for Apple. In `20261005T095956Z-apple` it is not pending with 0
    violations, the same result as before (`20261005T090214Z-apple`). It now drains the whole
    passage first: 55.6 s of audio before the trial ends, against 2.0 s before. For Kokoro it now
    produces a real pending cancel (`094912Z`, 0 ms). See R1 and O1.
  - (d) See Q1.

## Resolution

- Finding dispositions (lead):
  - R1 accepted, Required: record the cancellation trial's timing as specification drift.
  - O1 promoted to Required: the drain must not swallow a stream's error as a clean end.
  - O3 and O4 accepted as handoff corrections.
  - Q1 accepted: no store conflict with the running app, so repeat the first download on the
    final source by moving the installed Kokoro directory aside, rather than citing older
    evidence.
  - O2 left to the remediation agent's judgement while it edits the trial.
  - O5 noted for workstream 4; no change here.
- Changes:
  - R1: the handoff's trial Decisions bullet now points at Specification drift, which records
    the departure from the harness spec's "about 2 seconds" and why.
  - O1: `cancellationTrial` (`Speak.swift`) is one pull loop. Each `next()` runs in a task that
    returns its end time and a `Result`; a thrown error, in the paced part or while draining, goes
    to `check.threw` and ends the trial as not pending, so it is a violation rather than a clean
    end. The separate "pending" and "limit" tasks racing on a stream are replaced by one helper,
    `value(of:within:)`, used both for the 50 ms "is it waiting?" check and the 1 s cancel limit.
  - O2: taken in part. The trial no longer has `cancelledAt!` or a second post-loop phase; the
    pending case is handled where it happens. The two `map`s deciding `pending` and `latency`
    stay: further tidying would change source again and invalidate the final-source download run
    for a cosmetic gain.
  - O3: the Decisions bullet now says `cancel()` clears the stream's pending utterances, and that
    FluidAudio checks cancellation only between phoneme chunks of an over-long input.
  - O4: one Known limitations line on other FluidAudio tools writing into the store's Kokoro
    directory through the cache link.
  - Q1: the installed Kokoro directory and cache link were moved aside and
    `20261005T100655Z-local` downloaded, converted Emma's pack and recreated both links on the
    final source (started 10:06:12Z, after the last source edit at 10:02:59Z). It replaces the old
    download evidence, its Known limitations caveat and the old Emma paced run; first-audio figures
    under the bound now cite it. The set-aside copy was deleted after it verified.
- Simplification/deletion pass: the trial lost its second phase (signal stream, two racing tasks,
  fixed 50 ms sleep, post-hoc pending reconstruction); one generic timeout helper serves both
  waits. Nothing else in the workstream needed removal. No further source change was made in this
  pass.
- Final verification: passed, on the final source (last edit `Speak.swift` 10:02:59Z).
  - `swift build`; `swift test` (core 143, bench 23, app 76); `swift build -c release --product
    EchoTypeApp`.
  - `20261005T100655Z-local`: first download plus paced Emma, all 8, 0 violations, trial pending
    0 ms (`report`ed).
  - `20261005T130632Z-local`: paced Heart, two passages, 0 violations, trial not pending
    (`report`ed). Replaces `20261005T095138Z-local`, whose trial predated the O1 edit.
  - The `--fast` speed and offline runs (`095204Z`, `095208Z`, `094854Z`) stand: `--fast` never
    runs the trial, the only code changed since.

## Closure review

- Reviewer: fresh closure review agent (Claude Code), on the uncommitted diff over `b442628`.
- Verdict: Accept. Every accepted finding is fixed and the fixes add no release-blocking defect.
- Accepted findings:
  - R1 fixed: the Decisions bullet points at Specification drift. That section records the
    departure from the "about 2 seconds" wording in `docs/specs/test-harness.md` and
    `01-bench-speak.md`, and why. The lead still has to copy it into the plan's drift log at
    acceptance.
  - O1 (promoted) fixed: in `cancellationTrial` (`Speak.swift`), every `next()`, paced or
    draining, returns a `Result`. A failure goes to `check.threw` and ends the trial as not
    pending, so it counts as a violation rather than a clean end. The pending branch handles the
    race correctly: a pull that ends between the 50 ms check and `cancel()` is recorded as not
    pending. A pull that never ends gives `latency` nil and the existing over-limit violation.
    `value(of:within:)` leaves the waited-on task running, as its comment says. In the bench that
    is harmless.
  - O3 and O4 fixed in the handoff (Decisions and Known limitations).
  - Q1 resolved: `20261005T100655Z-local` (`startedAt` 10:06:55Z, preparation 43 s before it) is
    the first download and paced Emma run on the final source. Its `report` shows 8 readings,
    0 violations, 0 gaps and a pending trial at 0 ms (`cancellation.jsonl`: 10.9 s of audio
    before cancel).
- Run freshness, checked against file modification times: the last source edit is `Speak.swift`
  at 10:02:59Z. Both paced runs started after it: `100655Z` and `130632Z` (Heart, 2 readings,
  0 violations, trial not pending). The `--fast` runs `094854Z` (offline), `095204Z` (0.5x) and
  `095208Z` (2x) started after the last core edit (`KokoroSpeech.swift`, 09:45:16Z). They predate
  only the `Speak.swift` edit, and its trial runs only when `!options.fast` (`Speak.swift` line
  47), so they stand. Each run directory has `report.md`.
- Verification rerun here: `swift build`, `swift test` (core 143, bench 23, app 76, all passed)
  and `swift build -c release --product EchoTypeApp` all passed. I did not repeat the paced runs,
  for the reasons above.
- Remaining required findings: none.
