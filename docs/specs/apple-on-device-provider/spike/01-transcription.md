# Spike 1: Live transcription

Status: accepted, 2026-10-01. Frozen task packet completed as a feasibility spike.

## Task packet

### Outcome

Measured feasibility for S1 against the feature-complete Apple fallback requirement. Record answers and proposed implementation choices in the assigned specification results section, with no production implementation.

### Scope

Answer every S1 question with real-time-paced recordings, including pauses, silence, quick stop and cancellation. Measure cold/warm readiness, first-word and final-tail latency; establish committed/utterance/provisional mapping and speech evidence. Exercise built-in and saved keyterms and language resolution, and report hardware/asset/permission states. Compare xAI where credentials and the same recordings are available.

Probe the existing SessionMachine with a test-only adapter where necessary to establish event/lifecycle compatibility, rather than just transcribing a whole file. Preserve monotonic committed text and final tail. Investigate Test caller assumptions by reading DictationOperation; do not wire Apple into it. Answer setup/download/retry and proposed availability behavior with observed framework evidence, distinguishing policy recommendations from measured behavior.

### Non-goals

Production adapters, registry changes, shared contract changes, UI, deployments and production implementation packets. Do not reject solely for quality below xAI or silently omit required features. Do not promise behavior supported only by documentation or mocks.

### Initial ownership

Tests/EchoTypeCoreTests/Integration/AppleTranscriptionSpike.swift and test-only helpers under Integration/AppleTranscription/. Own the spec section `S1 results` immediately after S1 questions. Do not refactor existing integration helpers or create a general abstraction. Also own this packet, your plan row, gate entry and relevant escalation/drift entries. All writes are sequential. Any minimal signed experimental host stays within your Integration helper directory, with a documented command and no production edits.

### Required seams

Read the specification, adapter decision and Provider.swift through README links. Follow existing production contracts unchanged. Use the plan's opt-in environment convention and record no private audio or secrets. Results are input to the final feasibility matrix, not authorization to implement a production design.

### Acceptance criteria

- Every S1 question has measured evidence or a concrete observed limitation, including lifecycle and availability cases above.
- Experiments run on Aidan's Mac; unsupported configurations are reported separately from supported-path evidence. Unobserved states are explicitly marked, with nondestructive evidence or an approved limitation.
- Opt-in checks are disabled in ordinary test runs, including before service initialization or asset installation.
- Framework quirks remain in test-only Apple code. Record any necessary future shared or bundle changes and why.
- Record OS/hardware/toolchain, sample/configuration, measured timings and quality tradeoffs concisely in the spec. Keep reproducible synthetic cases; avoid ceremony and exhaustive permutations.
- Independent review and focused closure pass. Discovery of an unsupported feature is valid spike evidence but must be carried to the final decision gate, never presented as feature-complete support.

### Targeted verification

On a Mac with the repository's Swift 6.2 toolchain, add tests whose names include `AppleTranscriptionSpike`. Run:

```bash
swift test --disable-xctest --filter AppleTranscriptionSpike
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleTranscriptionSpike
git diff --check
```

The first command confirms the opt-in tests skip without starting services. The second runs live checks; recording-based tests additionally need ECHOTYPE_FIXTURE_WAV set to an existing local WAV. Add exact recording/comparison and signed-host commands to your handoff once the candidate exists, without literal secret values. If Mac execution is unavailable, prepare the candidate and block at its Mac gate. Do not treat compilation elsewhere as live validation.

## Implementation handoff

- Base commit: `51083b55b39afd49937b2eddf466d731d7993b10`.
- Candidate: that base plus `Tests/EchoTypeCoreTests/Integration/AppleTranscriptionSpike.swift`, `Integration/AppleTranscription/SpikeTranscriber.swift`, this handoff and the specification's S1 results. Accepted experiment; no production, package, resources or existing helper edits.
- Outcome: runnable opt-in inventory, contextual-string, installation and lifecycle checks, with a test-only adapter driven by the real SessionMachine. Real-time synthetic speech preserves monotonic committed text and the final tail. The supplied human recording, a fresh pause variant and a five-second prefix now pass Apple checks. xAI comparison remains unavailable.
- Decisions: append final segments and replace provisional text; leave utterance empty. Nonempty recognition supplies speech evidence. The paired SpeechDetector produced no events, and an initial detector-only candidate hit SessionMachine's no-speech cancellation at ten seconds. Framework silence rejection remains visible as a provider failure rather than being hidden. Regional locale policy and setup failure retry await final judgment and evidence.
- Inherited verification: ordinary filter run skips all five tests before framework initialization. Apple-only run passes inventory, lifecycle and context checks; recording and installation skip unless separately configured. Full synthetic run passes four checks with installation skipped. The explicitly opted-in fr-FR installation check also passes as an experiment, while recording that cancellation did not stop the download. `git diff --check` passes. The lead repeated the ordinary filter and confirmed all five skips. A helper README caused an unhandled-resource warning, so its instructions were moved into this packet and the file removed.
- Measurements: macOS 27.2 build 26B5091g, MacBookPro18,3, Apple M1 Pro with eight cores and 16 GB RAM, arm64, Swift 6.4, macOS SDK 27.0. Foundation Models reports available. Installed English model preparation took 82 to 125 ms in a fresh test process and 37 to 51 ms subsequently; process freshness does not prove cold system caches. Prompt start return took 0.09 to 2.18 ms. Loading cancellation requested at 10 ms joined at 38 to 39 ms from launch. Synthetic first word appeared at about 1.06 s from adapter launch. Final tail arrived 65 to 71 ms after finish; stop-to-outcome was 109 to 117 ms in the final pause test. Earlier default-timeout run measured 112 to 190 ms.
- Persistent state: initially installed English locale family, no reservations. Querying installation requests and installing fr-FR left `en_GB` and `fr_FR` reserved and added installed `fr_BE`, `fr_CA`, `fr_CH`, `fr_FR`. No explicit reserve/release call, asset removal, settings toggle, app launch or deployment occurred. Existing English assets remain installed. Request creation appears to reserve locales even when no download is needed, so a future availability check must account for that side effect.
- Setup evidence: missing fr-FR installation completed in 8.995 s despite cancelling its task after 100 ms; cancellation-to-join took 8.891 s. The new request after completion was nil. This supports allowing setup to complete after provider switching, but does not prove retry after a failed or interrupted download.
- Earlier missing evidence: Aidan's integration WAV and optional xAI key were absent from the environment; no WAV existed in the repository fixture locations. Human speech accuracy, comparison timings, real-room silence, usable recognition limit beyond context readback, genuine cold model loading, failed-download retry and unavailable-hardware behavior remain unmeasured. No signed experimental host was necessary for these file-input checks; production microphone and signed-bundle permissions still need later validation.
- DictationOperation assumptions: capture starts before `service.start`; SessionMachine's readiness timeout starts only after start returns. The candidate launches loading separately and returns promptly, keeping loading inside that timeout. Test schedules commit five seconds after its initial snapshot, suppresses insertion and cleanup, and does not expose cancel. Normal finish drains the capture tail before sendClosing. No caller-specific wiring was added.
- Simplification: one actor contains Apple work; existing WAVRecording and AudioConverter remain unchanged. Removed a shell helper that caused an unhandled-resource warning; reproducible synthetic instructions now live in this packet. No shared experimental abstraction, signed host or production flag.
- Specification drift: measurements used the available Swift 6.4 / SDK 27.0 toolchain, not the packet's Swift 6.2 wording. Synthetic speech supplements the human evidence; it never replaced the recording gate.

### Recovery evidence, 2026-10-01

Aidan supplied `orig_127389__acclivity__thetimehascome.wav` at `/Users/aidanzealley/.t3/userdata/attachments/93f56caa-32f4-4add-81b5-02ace679998e-c935c317-5da4-4f1b-a30e-d82591437b6a-wav.wav`, outside the repository. It is 4,937,944 bytes, 27.993 seconds, 44.1 kHz stereo PCM16. SHA-256 is `a4056ff0022e9d602c7128ebf0253328e57f8ad4f2fce8a6f3228384016ed483`. Existing WAVRecording and AudioConverter read and convert it to the unchanged 16 kHz mono adapter input.

The current worktree, including ignored files, the other registered worktree and all reachable git object paths contained no WAV or silence-added audio. Historical commit `bb8b43be6eed354936b6958a6dcda0e3aa12be8d` documents a public-corpus human voice with two 3.5-second zero-filled pauses at `~/echotype-fixtures/sample-with-pauses.wav`. That directory is gone. The attachment is human speech, but it is not proof that we recovered the exact earlier fixture. A fresh `/tmp/echotype-s1-human/with-pauses.wav` preserves every attachment sample and inserts 3.5-second pauses after original times 6 and 12 seconds, producing 34.993 seconds. `/tmp/echotype-s1-human/five-seconds.wav` is its original five-second prefix. Source audio is unchanged. Raw audio and logs remain outside git.

| Check | Measured result |
|---|---|
| Original human recording, no context and built-in/saved context | Both passed. First word 1.960 to 1.987 s after adapter launch; final tail 60 to 73 ms after finish; stop-to-outcome 144 to 151 ms. |
| Human recording with fresh pauses, same two contexts | Both passed with monotonic committed text and complete final insertion. Two paused snapshots per run returned to listening. First word 1.974 to 1.997 s; final tail 73 to 75 ms; stop-to-outcome 152 to 154 ms. SpeechDetector still produced no events. |
| Five-second human prefix, same contexts | Both resolved provisional text into insertable final text. Final tail 90 to 92 ms; stop-to-outcome 97 to 99 ms. This measures the adapter path used by Test, not signed DictationOperation wiring. |
| Cancellation after five seconds of human audio | New focused opt-in check passed with `.nothing`, repeated close and joined adapter work. Cancel-to-join was 1.77 ms. |
| Quality and context | All four full-length runs returned the same normalized 43 words, with punctuation differences. Context did not change words. No independent reference transcript was supplied, so no word-error rate or jargon improvement is claimed. The sample does not exercise the saved jargon terms. |
| Containment | Original full opt-in run passed four checks and skipped installation. Pause checks passed; five-second finish and active-cancellation checks passed. Final ordinary run skipped all six checks before service initialization; `git diff --check` passed. No download flag, asset removal, settings change, production write or deployment occurred in recovery. |

Apple readiness during the original full run was 38 to 99 ms. OS and toolchain match the inherited measurements. `XAI_API_KEY` remains absent, and the historical `~/secrets/secrets.env` file is absent, so no xAI request ran. Historical xAI timings used a different derived fixture and are not a same-recording comparison.

Aidan accepted the named unobserved cases on 2026-10-01, provided later validation accounts for them. He did not waive human evidence. The supplied recording now supplies that evidence; these limitations remain for final judgment and later validation:

| Limitation | How later validation accounts for it |
|---|---|
| Genuine cold installed-model load | Time first dictation after a normal restart on a configured Mac. Keep start prompt and loading within the existing five-second readiness timeout; do not remove assets to force cold caches. |
| Failed-download retry | On an authorized missing-model setup, observe a real failure and subsequent reselect/operation retry. Successful completed installation does not establish retry behavior. |
| Unsupported hardware | Query availability on a supported older Mac that lacks SpeechTranscriber support, then verify the provider-neutral unavailable reason before capture. |
| Human jargon recognition and usable context limit | Supply a human jargon recording and reference transcript, compare no-context with built-in/saved terms at the proposed cap, and increase list size only to establish a useful cap. Readback of 1000 strings proves transport only. |
| Room silence | Supply microphone room tone and speech with natural pauses. Confirm empty-silence behavior and speech evidence before deciding whether any RecogRejected case may mean empty completion. |
| Signed microphone permissions and Test | During production verification, use the signed bundle for microphone dictation, a five-second Test, cancellation and prompts. Add bundle permission declarations only if the observed path requires them. |
| xAI accuracy and latency comparison | Repeat the same retained WAVs with the existing xAI check when credentials are available, with a human reference for word-error counts. |

Reproduction uses the packet's existing commands with the attachment or `/tmp/echotype-s1-human/with-pauses.wav`; use `ECHOTYPE_SPIKE_SILENCE_TIMEOUT=2` only for the pause variant. Run `ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-human/five-seconds.wav swift test --disable-xctest --filter 'recording.*AppleTranscriptionSpike'` for five-second finish and active cancellation. Logs are `/tmp/echotype-s1-human-original.log`, `/tmp/echotype-s1-human-pauses.log` and `/tmp/echotype-s1-human-five-seconds.log`. No signed host was needed. Independent review and fresh closure passed; the lead accepts S1 evidence within the named limitations.

## External validation

- Gate and placement: Mac measurement, before independent review.
- Status: Passed. Supplied human recording, fresh pause variant, five-second finish and active cancellation ran on Aidan's Mac. Named unobserved cases remain explicit under Aidan's recorded acceptance, with later validation in Recovery evidence.
- Candidate: base `51083b55b39afd49937b2eddf466d731d7993b10` plus the owned files above. Compilation and real framework execution on Aidan's Mac are established.
- Exact checks from the repository root:

```bash
swift test --disable-xctest --filter AppleTranscriptionSpike
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleTranscriptionSpike > /tmp/echotype-s1-local.log 2>&1
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV="/absolute/path/to/private-dictation.wav" \
  ECHOTYPE_SPIKE_LANGUAGE=en-GB \
  swift test --disable-xctest --filter AppleTranscriptionSpike > /tmp/echotype-s1-recording.log 2>&1
# With XAI_API_KEY already configured in the shell, run the same WAV through the existing check.
ECHOTYPE_FIXTURE_WAV="/absolute/path/to/private-dictation.wav" \
  swift test --disable-xctest --filter liveStreamingSessionRecordsItsEventSequence > /tmp/echotype-s1-xai.log 2>&1
git diff --check
```

The existing xAI check uses Settings' default language `en`; Apple defaults to explicit `en-GB` for reproducibility. Compare English recordings and record that regional difference. No key belongs in the command or report. Synthetic instructions follow below.

An installation probe requires an additional explicit flag because it downloads and retains assets. fr-FR is already installed after this attempt. Repeating it proves only that the request is nil; it cannot remeasure cancellation without another genuinely missing supported locale. Do not remove assets to force that state.

```bash
# Choose a missing supported locale only when its installation is wanted.
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_SPIKE_INSTALL_LANGUAGE=fr-FR \
  swift test --disable-xctest --filter installationAppleTranscriptionSpike > /tmp/echotype-s1-install.log 2>&1
```

- Required output: keep raw logs/audio outside git. Return a concise summary of recording duration, language, reference text or word-error count, first-word and final-tail timings, pause events, final insertion, keyterm changes, environment and missing observations. Include the xAI comparison if credentials are available. The test logs all framework results with monotonic elapsed time and SessionMachine snapshots.
- Attempts: initial inventory showed nondeterministic bare-language matching. Initial detector-only recording failed by auto-cancelling, then the smallest correction used observed recognition as speech evidence and passed. Installation cancellation completed the download rather than cancelling it. The final synthetic check also shows paused-to-listening recovery under a two-second test silence timeout. No system setting was changed.
- Gate resolution: Aidan supplied the human fixture and accepted the named limitations with later validation. Recovery evidence records both. Failed-install retry is not claimed from successful installation. No signed-host instructions are needed unless later file or microphone experiments establish that requirement.

### Synthetic recording reproduction

Use a private integration recording with two pauses of at least three seconds for the comparison gate. Export 16-bit PCM WAV. The existing test helper resamples other sample rates by linear interpolation, so prefer 16 kHz mono for an accuracy comparison. Audio and reports stay outside the repository.

This synthetic recording reproduces the separate framework measurements. It is not evidence of accuracy on Aidan's dictation. The current default `say` voice determines pronunciation, so record that choice when comparing another Mac.

```bash
mkdir -p /tmp/echotype-s1-synthetic
/usr/bin/say -o /tmp/echotype-s1-synthetic/first.aiff 'EchoType lets me dictate notes. I use Zustand and TanStack in my projects.'
/usr/bin/say -o /tmp/echotype-s1-synthetic/last.aiff 'The final words must survive when I stop recording.'
for name in first last; do
  /usr/bin/afconvert -f WAVE -d LEI16 -r 16000 "/tmp/echotype-s1-synthetic/$name.aiff" "/tmp/echotype-s1-synthetic/$name.wav"
done
python3 - <<'PY'
import wave
root = '/tmp/echotype-s1-synthetic'
with wave.open(f'{root}/recording.wav', 'wb') as output:
    output.setparams((1, 2, 16000, 0, 'NONE', 'not compressed'))
    for name in ['first', 'last']:
        with wave.open(f'{root}/{name}.wav', 'rb') as source:
            assert source.getnchannels() == 1 and source.getsampwidth() == 2
            output.writeframes(source.readframes(source.getnframes()))
        output.writeframes(bytes(3 * 16000 * 2))
PY
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-synthetic/recording.wav \
  ECHOTYPE_SPIKE_SILENCE_TIMEOUT=2 \
  swift test --disable-xctest --filter AppleTranscriptionSpike > /tmp/echotype-s1-synthetic.log 2>&1
```

The two-second test timeout makes the three-second pauses visible in SessionMachine snapshots. Ordinary recording checks use the unchanged ten-second default. A fixture with more than two seconds of initial silence should use the default.

## Independent review

- Reviewer: fresh independent review agent, 2026-10-01.
- Candidate reviewed: base `51083b55b39afd49937b2eddf466d731d7993b10` plus the complete uncommitted S1 diff, including both new Swift files, S1 results, this packet and plan changes. Read the workflow, specification, adapter decision, Provider.swift, SessionMachine and DictationOperation.
- Verdict: pass for S1 spike acceptance under Aidan's recorded acceptance of named limitations. No required defect or containment violation found. This accepts measured feasibility evidence, not production readiness or a feature-complete shipping claim.
- Required findings: none. Apple work remains inside the owned test files. Ordinary runs disable the suite before analyzer construction or asset requests. The adapter supplies ready before transcript events, append-only committed text, resolved finish tails and joined cancellation on the observed path. Existing production contracts and callers remain unchanged.
- Optional observation O1: the cancellation check starts `machine.run()` in a task and immediately sends audio, without waiting for its initial snapshot. SessionMachine ignores sends while idle, so scheduling can discard the first 100 ms. This does not undermine cancellation during established speech in the measured run. If this check later measures onset or exact audio coverage, synchronize with the initial snapshot first.
- Questions: none blocking S1. Regional matching, setup retry and empty-silence policy remain decisions for the final gate, with the unobserved cases and later validation already named in Recovery evidence.
- Evidence assessment: inspected retained original, pause and five-second human logs. They support the reported context transport, two pauses per context run, monotonic committed snapshots and insertion of the final resolved tail. Missing xAI credentials prevent a same-recording comparison. Human jargon effect, recognition limit, genuine cold caches, failed-download retry, unsupported hardware, room silence and signed microphone/Test permissions remain explicit limitations with concrete follow-up. Context readback is not recognition-limit evidence; successful installation after cancellation is not failed-download retry evidence. No framework behavior was inferred from external documentation.
- Independent verification: `swift test --disable-xctest --filter AppleTranscriptionSpike` passed with all six tests skipped. Repeated `ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-human/five-seconds.wav swift test --disable-xctest --filter 'recording.*AppleTranscriptionSpike'`; both tests passed in 15.456 s. Both context variants inserted the resolved five-second tail, stop-to-outcome was 94 to 148 ms, and active cancellation joined in 1.02 ms with `.nothing`. Raw review logs remain at `/tmp/echotype-s1-review-disabled.log` and `/tmp/echotype-s1-review-human.log`. `git diff --check` passed. No installation flag, asset removal, settings change, app launch or deployment was used for this review.

## Resolution

- Required findings: none; no remediation pass needed.
- Optional O1: deferred. The cancellation experiment establishes cancellation after five seconds, so its possible initial 100 ms scheduling loss does not affect the acceptance claim. Synchronize initial snapshot only if this check later measures onset or exact coverage.
- Simplification/deletion pass: reviewed the two test-only files. One focused actor and existing recording/conversion helpers suffice; no façade, duplicate state or general infrastructure was added. The earlier helper README was removed after its SwiftPM resource warning, leaving commands in this packet.
- Gate resolution: human measurements completed after Aidan supplied the WAV. His accepted limitations remain in Recovery evidence with concrete later checks. No production readiness claim follows from this spike acceptance.
- Verification: independent review repeated the normal filter and five-second human finish/cancellation checks; all passed or skipped as intended. `git diff --check` passed. Fresh closure passed with no required findings.

## Closure review

- Reviewer: fresh focused closure review agent, 2026-10-01. Reviewed the complete S1 candidate against `51083b55b39afd49937b2eddf466d731d7993b10`, the source specification, adapter decision, Provider.swift and surrounding SessionMachine/DictationOperation code.
- Verdict: pass for S1 spike acceptance under Aidan's recorded acceptance of the named limitations. Remaining required findings: none. Test-only containment, opt-in gating and the measured event/lifecycle contract hold; production readiness remains unproven.
- Evidence: retained original, pause and five-second human logs support final-tail insertion and active cancellation with `.nothing`. Checked all 313 recorded snapshots for monotonic committed prefixes; the pause log contains two paused snapshots in each context run. The independent review's repeated five-second check confirms recognition before cancellation and a 1.02 ms joined cancellation. These observations support the cancellation claim despite O1's possible first-chunk loss.
- Resolution confirmed: O1 stays optional and deferred. No remediation was required. Recovery evidence records Aidan's decision and concrete later validation for cold loading, failed-download retry, unsupported hardware, human jargon/context limits, room silence, signed microphone/Test permissions and xAI comparison. Context readback and completed installation are not presented as recognition-limit or failed-retry measurements. Regional matching and empty-silence policy still await the final decision gate.
- Closure verification: `swift test --disable-xctest --filter AppleTranscriptionSpike` passed with all six tests skipped before service initialization; log at `/tmp/echotype-s1-closure-disabled.log`. `git diff --check` passed. Retained live evidence was inspected rather than rerunning asset setup or the full recording suite. This review changed only this section.
