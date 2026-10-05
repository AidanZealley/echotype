# Workstream 5: Transcription evaluation and results

Status: Accepted. Evaluation and both reviews passed. Boosted recommendation recorded; build selection unchanged. GUI restored; original MCP stdio transport needs reconnection.

## Task packet

### Outcome

`docs/spikes/local-models/results.md` has a transcription section that compares Parakeet Unified
(with and without keyterm boosting) and Whisper Turbo with Apple and xAI on Aidan's corpus, and
measures cleanup running alongside the preferred transcriber. It ends with a recommendation. The
cleanup section gains release-build timing for Qwen3. Every figure cites the run it came from.

### Scope

Run everything from a release build of the bench (`swift run -c release EchoTypeBench ...`), on the
machine as it is; do not wait for it to be quiet. Record each run's load average from `report`.

1. **Standalone transcription,** one paced pass over every reviewed dictation sample for
   `parakeet-unified`, `parakeet-unified-keyterms` and `whisper-turbo`. One pass gives about 14
   warm samples per run: enough for accuracy and p50, while p95 is close to the slowest sample;
   say so beside the figures. The baselines are existing paced runs, both one pass from a debug
   build before the sampler existed, so they have no cold split, memory or load figures: Apple
   `20261004T083627Z-apple` (Apple's model runs outside the bench process, so the build barely
   affects it) and xAI `20261004T073341Z-xai`. Do not run xAI.
   If two candidates are too close to choose between on one pass, add `--repeat 3` runs for those
   candidates only, and record why.
2. **First download and cold start,** for each transcription candidate and for `qwen3-4b-2507`:
   move its installed directory aside under the README's download rule, then run one sample
   (`dictation-short-reply`, or a `cleanup` sample for Qwen3) to capture download and first load,
   then the same again in a fresh process to capture a load from installed files. Record download
   time and size, first-load time (and whether Core ML compiled anything), the cold load, and disk
   used including any compiled caches. For one transcription candidate, also kill the bench
   partway through its download and rerun: record that the partial files were not loaded and the
   model installed and verified (slice 1 tested this only with an injected source). A first load
   after a reboot or OS update is not measured; say so.
3. **Offline,** for each transcription candidate: a `--fast` run with network access denied
   (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on the built release binary),
   checked against its online run.
4. **Choose the preferred transcription candidate** from steps 1-3, with reasons, before step 5.
5. **Concurrent dictation,** one paced pass with the dictation run from workstream 3: the
   preferred candidate with `qwen3-4b-2507`, and Apple with Apple cleanup for comparison.
6. **Cleanup in release:** `cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 15`,
   paced, to set beside slice 1's debug run `20261004T110130Z-local`.
7. **Write results.** Add a transcription section to `results.md` in the cleanup section's style
   and add the release cleanup timing to the cleanup section without removing the debug figures.
   Update the file's status line and the conditions that limit the figures (debug or release, and
   load average, per run). Correct `research.md` where a measurement contradicts it, as slice 1
   did.

The transcription section covers:

- runs, candidates (repository, revision, licence and any licence conflict, download and disk
  size, keyterm limit, live-handling settings), dependency pins and integration changes;
- accuracy: word error rate, formatted word error rate, keyterm accuracy, silence insertions and
  changed committed text, overall and per sample where a sample explains a difference;
- the references' bias: they began as xAI drafts that Aidan corrected, so xAI's error rates are
  flattering. State it beside every comparison with xAI;
- keyterm boosting: what it changed in keyterm accuracy and error rate, and what it cost in commit
  lag (first committed text and the gap between speech and committed text);
- latency: first provisional, first committed and stop-to-final, warm p50/p95/n with the cold
  sample apart;
- cost: preparation, download, first load, cold load, footprint peak and ready, memory pressure
  and thermal state, noting that Core ML work on the Neural Engine may be charged to system
  processes, so process footprint can understate it;
- concurrent dictation: stop-to-insert and its parts, deadline fallbacks and overruns,
  cancellation latency, revising share and combined footprint, against slice 1's standalone
  cleanup figures and Apple's dictation run;
- the signed-app check's outcome, from [04-app-provider.md](04-app-provider.md)'s External
  validation section;
- a recommendation: the preferred transcription candidate and keyterm setting, whether the
  build's default selection should change, the remaining gap to xAI and Apple stated plainly, and
  whether any spec follow-up (Unified's offline re-decoding, Nemotron or Ultra) is triggered by a
  measurement, using the spec's conditions.

### Non-goals

- Product code changes. A bench defect that blocks a run is fixed with the smallest change and
  recorded in the handoff; anything larger is an escalation.
- Read aloud, the voice comparison build, energy, or new paid runs.
- Changing `LocalSelection.build`; recommend instead.

### Initial ownership

- `docs/spikes/local-models/results.md` and `docs/spikes/local-models/research.md`.
- `Sources/EchoTypeBench/` only for a blocking defect as above.

### Required seams

- Consumes the candidates and bench as workstreams 1-4 built them; read their handoffs for
  settings, report fields and the signed-app outcome.

### Acceptance criteria

1. Every run in scope exists and is cited by id, and every new run was a release build; every figure, bullet and
   table row in the new and changed sections names its run, including derived figures.
2. The transcription section covers every bullet above, including the reference bias, keyterm
   boosting's cost, concurrent dictation and the signed-app outcome.
3. Each recommendation follows from cited figures, and claims are scoped to what was measured.
4. Unmeasured items (first load after reboot, energy, read aloud) are named as not measured.
5. No recording, reference text or personal content beyond sample ids and short excerpts `report`
   prints appears in the documents.

### Targeted verification

```bash
swift build -c release --product EchoTypeBench
swift run -c release EchoTypeBench report <each cited run id>
```

Check that each figure in `results.md` matches its `report` output or, for derived figures, the
run's log.

## Implementation handoff

- Base commit: `6c779359fe0035fed7fcc127dac606c37b7594e0`, `spike/local-models`.
- Outcome: release transcription evaluation is complete. `results.md` compares all three local
  selections with the existing Apple and xAI baselines, records offline use, fresh downloads,
  paired installed loading, real interruption recovery, concurrent dictation and release cleanup.
  Applied `unslop` to the results and this record. No product or bench code changed.
- Existing evidence retained, without unnecessary reruns:
  - Paced standalone selections: `20261005T061114Z-local`, `20261005T061642Z-local`,
    `20261005T062416Z-local`.
  - Online-fast / network-denied pairs: `20261005T061546Z-local` / `20261005T061600Z-local`,
    `20261005T062117Z-local` / `20261005T062139Z-local`,
    `20261005T063149Z-local` / `20261005T063537Z-local`.
  - Qwen release cleanup: `20261005T063709Z-local`, compared with debug
    `20261004T110130Z-local`.
  - Concurrent boosted Unified/Qwen: `20261005T064539Z-local`. Apple/Apple:
    `20261005T065030Z-apple`. Selection was recorded before the local concurrent run in its
    `evaluation-selection.json`.
  - Existing transcription baselines: `20261004T083627Z-apple` and paid
    `20261004T073341Z-xai`. No xAI request was made. References began as corrected xAI drafts,
    so its error rates are flattering.
- New delivery evidence, fresh / paired installed run:
  - Unified without boosting: `20261005T071509Z-local` / `20261005T071516Z-local`.
  - Unified with boosting: `20261005T071635Z-local` / `20261005T071726Z-local`.
  - Whisper Turbo: `20261005T072008Z-local` / `20261005T072029Z-local`.
  - Qwen: `20261005T072145Z-local` / `20261005T072155Z-local`.
  - Separate real interrupted Unified retry: `20261005T072301Z-local`. After four seconds,
    SIGKILL left Unified absent from installed directories and five verified files under
    `Incomplete/`. The retry completed and every pinned file passed size/SHA-256 verification.
    `evaluation-interruption.json` saves the interrupted state beside the retry run.
  - Each fresh selection moved all of its required directories aside, including shared Silero.
    Existing verified files, earlier copies and runs remain intact. New preserved copies are
    under `~/Library/Application Support/EchoType/Evaluation-20261005-exclusive/`.
- Recommendation and decisions:
  - Prefer `parakeet-unified-keyterms` for live use. Boosting improves keyterms from 57.9% to
    84.2% and WER from 6.9% to 6.1%, at the cost of later commitment and a warm median tail
    of 283 ms instead of 47 ms (`20261005T061114Z-local`, `20261005T061642Z-local`).
    Whisper has stronger WER/keyterms, 2.7%/94.7%, but a 3383/5099 ms warm tail
    (`20261005T062416Z-local`). The tradeoff was clear enough that additional repeats were
    unnecessary.
  - Aidan authorized temporarily stopping the identified GUI and MCP processes for delivery
    experiments and relaunching afterward. After delivery evidence and both reviews passed,
    he chose to record the boosted recommendation and leave the build selection unchanged.
    Productionising belongs to a separate task. No boosted build follow-up or new signed-app
    gate is authorized in this workflow. No change to `LocalSelection.build`, the normal provider
    default or model-store architecture was made.
  - Offline inference passed for each selection. Whisper's final text differed on three of
    fifteen samples; do not attribute that variation to network denial without another study
    (`20261005T063149Z-local`, `20261005T063537Z-local`).
  - Local concurrent final cleanup met its deadline on every sample, with zero fallbacks and
    overruns (`20261005T064539Z-local`). This does not prove cancellation during an over-budget
    request. No speculation follow-up is triggered by these final requests.
  - Unified's recognition/formatted-text gap justifies proposing offline re-decoding and Ultra
    as later quality experiments. Nemotron's sustained-cost condition remains unproved.
- Bench fixes, if any: none. No dependency or build-selection code changed.
- Simplification/deletion pass: replaced the obsolete blocked-delivery account with measured
  evidence, retained slice 1 debug figures and all valid installed-model runs, and removed
  conditional wording tied to missing delivery proof. No product machinery or tests were added.
- Verification:
  - `swift build -c release --product EchoTypeBench` passed.
  - `swift run -c release EchoTypeBench report <id>` passed for every cited run, including all
    delivery runs, existing baselines and eleven slice 1 cleanup runs.
  - Every new run records release configuration and the same source revision. Reports provide
    per-run load, footprint, pressure and thermal state. Figures match reports or saved derived
    logs. Prefix inspection found no changed committed text, errors or contract violations.
  - `evaluation-delivery.json` in each new run records download/loading phases, allocated disk,
    shared cache size and changed files. Readiness time includes transfer, verification and
    installation; source `.mlmodel` compilation is unnecessary because the artifacts ship as
    `.mlmodelc`. Runtime executable cache output was observed, but compiler time was not
    isolated from load/warm-up. Existing system caches were preserved.
  - All five acceptance criteria were checked. Every cited run exists; all new runs are release.
    Results cover every required measurement and comparison, scope recommendations to evidence,
    name unmeasured checks, and include no private corpus content.
  - Every installed pinned file passed independent size/SHA-256 verification after delivery.
    `git diff --check` passed. Scripts/logs are in `.build/transcription-evaluation/`, outside git.
    Runs were persistent subprocesses, with completion waits, not command-log polling loops.
- Process restoration and limitation:
  - Before stopping, checked exact paths and arguments. GUI PID 4045 was
    `/Applications/EchoType.app/Contents/MacOS/EchoTypeApp`; PIDs 186, 17960 and 37504 were
    same-path `.build/EchoType.app/Contents/MacOS/EchoTypeApp --mcp` stdio clients owned by
    the Codex harness. Only these authorized processes were stopped, using SIGTERM.
  - Source inspection confirmed `MCPProcess` creates no app, settings or model services; its
    stdio clients are not store writers. No other store writer appeared during the experiments.
  - The intended installed GUI relaunched successfully as PID 46492. No obsolete comparison
    app or duplicate GUI was launched. The original MCP binary passed initialize/tools-list
    protocol verification, without speaking.
  - Original MCP stdio transports could not be reattached through exposed tools. A replacement
    guardian/server was stopped because it was unattached and could not serve those original
    clients. GUI restoration succeeded; harness MCP restoration did not. Reconnect EchoType MCP
    or start a new agent session. Evidence is `process-restoration-verification.json`.
- Remaining limitations and external checks:
  - The earlier failed download retry remains preserved. It failed before a run id existed;
    prior interference evidence is in `.build/transcription-evaluation/`. The successful
    replacement test does not erase it or prove concurrent model-store installation safe.
  - Signed-app validation passed with switching-during-download explicitly waived. It covered
    unboosted Unified/Qwen and Whisper/Qwen, not a separate boosted signed build.
  - First load after reboot or OS update, energy, read aloud and Developer ID notarisation
    remain unmeasured. Process footprint can omit Core ML work charged to system processes.
    Small warm n makes p95 close to the slowest observation. Speech-event gaps are timing
    proxies, not word-aligned acoustic lag. No repeat isolates Whisper's fast-run variation.
- Specification drift: none. Delivery evidence meets the frozen measurement scope.
  Aidan's evaluation-only decision, signed-app waiver and MCP reconnection are stated separately.

## Independent review

- Reviewer: fresh independent Codex agent, 2026-10-05. Applied `unslop`.
- Verdict: pass against the frozen measurement packet. No Required findings.
- Required findings: none.
- Optional observations: none. Existing limitations require no extra experiments in this workstream.
- Questions: none. MCP transport reconnection is already identified as an external restoration
  requirement; this review does not claim it succeeded.
- Scope: inspected the complete uncommitted diff and status against
  `6c779359fe0035fed7fcc127dac606c37b7594e0`, including untracked files. Only results, research,
  this packet and the lead's plan record are dirty. No product, dependency, bench, model-store or
  build-selection code changed. Read the source-of-truth documents, dependency handoffs and plan
  conventions, and inspected the surrounding measurement, model-store and MCP code. No extra
  abstraction, test or speculative machinery was added.
- Acceptance criterion 1 passed. Independently ran
  `swift build -c release --product EchoTypeBench` and
  `swift run -c release EchoTypeBench report <id>` for all 34 run ids cited in `results.md`,
  including the eleven slice 1 cleanup runs and both transcription baselines. Every report passed.
  All 21 new runs record `release` and the frozen base revision. Their dirty source flag is
  consistent with the documentation-only diff. The legacy baselines lack configuration/sampler
  fields and are explicitly described as debug evidence. The new figures and rows cite their
  runs. Reports are saved in `.build/transcription-evaluation/independent-review/` outside git.
  Checked new quality, warm/cold timing, preparation, memory, load, pressure, thermal and concurrent
  figures against those reports. Recomputed provisional and speech-to-commit percentiles from
  raw events, offline final-text matches of 15/15, 15/15 and 12/15, and concurrent maxima of
  2008 ms final revision and 2716 ms insertion. These agree with the saved derived logs and results.
  Delivery phase and allocated-disk figures agree with each run's `evaluation-delivery.json`;
  download elapsed time starts at readiness, explaining its few milliseconds of difference from
  report's first progress-message timing.
- Acceptance criterion 2 passed. Results cover pinned repositories, revisions, licences and the
  Unified licence conflict, selected payload and disk/cache sizes, dependency pins, live settings,
  accuracy and illustrative sample differences, zero changed committed prefixes, boosting's
  commitment cost, provisional/committed/tail timing, fresh and installed loads, process cost,
  offline use, concurrent cleanup and the signed-app outcome. The xAI reference bias accompanies
  its comparisons. Small warm counts and the speech-event timing proxy are stated beside the
  latency evidence. Independently checked every new transcript's errors, contract violations and
  grow-only committed text. The signed-app account agrees with workstream 4, including the download
  switching waiver and absence of a separate boosted signed build.
- Acceptance criterion 3 passed. Boosted Unified's vocabulary gain and sub-second tail, versus
  Whisper's better accuracy and multi-second tail, support the proposed live selection. The
  candidate record predates the concurrent run and retained a conditional recommendation pending
  delivery evidence. That evidence is now present. Recommendations leave selection approval
  deferred and change no default. The concurrent deadline claim is limited to observed final
  requests, with no claim to have exercised over-budget cancellation. Offline re-decoding and Ultra
  are proposed quality follow-ups; Nemotron's sustained-cost condition remains unproved. Separate
  debug/release cleanup runs are not presented as a controlled compiler experiment.
- Acceptance criterion 4 passed. First load after reboot or OS update, energy and read aloud are
  explicitly unmeasured. Shared Core ML cache use, process-attributed memory and single paired
  startup observations are qualified. Cache file creation supports runtime specialization but
  does not isolate compiler duration.
- Acceptance criterion 5 passed. The changed documents contain sample ids and aggregate scores,
  with no new private corpus text or recordings. Existing slice 1 short excerpts are retained.
- Delivery and lifecycle: checked all nine fresh/installed/retry records and the interrupted-state
  log. SIGKILL left Unified absent from installed directories and five files totaling 14444100
  bytes under `Incomplete/`; the retry completed. ModelStore loads only installed directories
  after the verified-directory rename. Independently rechecked sizes and SHA-256 for every pinned
  installed file across all seven manifests. Existing copies and runs remain preserved. The
  earlier interference failure is retained and does not become proof of cross-process store safety.
  No new inference/download experiments or process stops were performed by this review.
- Restoration limit: `process-restoration-verification.json` records the installed GUI restored,
  original-binary initialize/tools-list passing, original harness stdio unattached, and the
  unattached replacement removed. Source inspection confirms MCPProcess creates no model services.
  Reconnection or a new session remains necessary to restore the original MCP clients. This is an
  operational follow-through issue for the lead, separate from Local voice in the next workflow
  and from the measured transcription acceptance criteria.
- `git diff --check` passed. The review edits only this section; no commit was made.

## Resolution

- Finding dispositions: independent review passed all five frozen acceptance criteria with no
  Required findings, Optional observations or Questions. No remediation is needed.
- Simplification/deletion pass: accepted the implementation pass. The documents retain sound
  existing measurements and replace obsolete blocked-delivery wording with cited evidence;
  no product machinery, model-store change or extra tests were added.
- Final verification: release build and all 34 cited reports passed in implementation,
  independent review and focused closure. No remaining Required findings. Aidan resolved
  ET-T5-02 by accepting the evaluation-only work with the recommendation recorded and build
  selection unchanged. The lasting decision is in the handoff and plan; the escalation is removed.
- Acceptance recovery: HEAD still matches the recorded base. The complete diff contains only
  the four owned documentation files, with no untracked files or intervening source changes.
  Existing review records and saved reports remain valid. Checked every cited run's presence
  and retained release/base metadata, plus the restoration evidence and `git diff --check`.
  No benchmark, app launch, model operation, new MCP client or extra review was needed.
- Operational follow-through: the installed GUI was restored. Original MCP stdio transport
  reconnection remains unresolved and is separate from Local read aloud, which is unavailable
  in this slice and belongs to the next workflow. A protocol-only check does not restore the
  original connector. This limitation does not block the measurement acceptance criteria.

## Closure review

- Reviewer: fresh focused Codex agent, 2026-10-05. Applied `unslop`.
- Verdict: pass. No release-blocking defect in the finished measurement documents or evidence.
- Remaining required findings: none. Independent review accepted all five frozen criteria and
  raised no Required findings, Optional observations or Questions. Resolution correctly requires
  no remediation; there are no fixes to recheck.
- Targeted verification: `swift build -c release --product EchoTypeBench` passed, followed by
  `swift run -c release EchoTypeBench report <id>` for all 34 run ids cited in `results.md`.
  Every report passed. All 21 new runs record release configuration and the frozen base revision.
  Checked the changed release quality, timing, preparation, footprint, load, pressure and thermal
  figures against reports, and the commitment, delivery and interruption claims against saved
  derived and delivery records. No discrepancy changes the recommendation or acceptance.
- Scope and limits remain explicit. The diff changes documentation only; build selection is
  unchanged and boosting remains a proposal requiring the deferred selection decision. The
  signed-app waiver, biased xAI references, unmeasured reboot loading, energy and read aloud, and
  limits of deadline and process-footprint evidence remain recorded.
- Restoration evidence agrees with the handoff. The installed GUI was restored, the original
  binary passed a protocol-only check, and the unattached fallback was removed. Original harness
  MCP stdio connections remain unattached and require user reconnection or a new session. This
  operational requirement is separate from future Local voice and measurement acceptance.
- No new experiment, process stop, product change or scope expansion. `git diff --check` passed.
  This review edits only this section and makes no commit.
