# Spike 2: Read aloud

Status: accepted. Frozen task packet, workflow approved.

## Task packet

### Outcome

Measured feasibility for S2 against the feature-complete Apple fallback requirement. Record answers and proposed implementation choices in the assigned specification results section, with no production implementation.

### Scope

Answer every S2 question, prioritizing Siri access through buffer synthesis. If Siri is inaccessible, test the best available installed alternatives and record their ids and quality tradeoff. Measure first-buffer latency, format/sample rate, speed mapping and range, text limit, missing-voice detection and language fallback without overwriting saved choices.

Exercise a test-only SpeechStream with a long utterance: pause pulls, record peak buffered audio and synthesis behavior, resume without loss, cancel while next() is pending, and start another reading. Verify mono Float32 conversion, constant sample rate and chunks at most 100 ms. Inspect Reader and MCP speech entry points for compatibility; actual app/MCP integration remains future verification. Record offline behavior after assets are installed. Lower voice quality is not a blocker.

### Non-goals

Production adapters, registry changes, shared contract changes, UI, deployments and production implementation packets. Do not reject solely for quality below xAI or silently omit required features. Do not promise behavior supported only by documentation or mocks.

### Initial ownership

Tests/EchoTypeCoreTests/Integration/AppleVoiceSpike.swift and test-only helpers under Integration/AppleVoice/. Own the spec section `S2 results` immediately after S2 questions. Do not change Reader, SpeechPlayer, MCP handlers or production voice lists. Also own this packet, your plan row, gate entry and relevant escalation/drift entries. All writes are sequential. Any minimal signed experimental host stays within your Integration helper directory, with a documented command and no production edits.

### Required seams

Read the specification, adapter decision and Provider.swift through README links. Follow existing production contracts unchanged. Use the plan's opt-in environment convention and record no private audio or secrets. Results are input to the final feasibility matrix, not authorization to implement a production design.

### Acceptance criteria

- Every S2 question has measured evidence or a concrete observed limitation, including lifecycle and availability cases above.
- Experiments run on Aidan's Mac; unsupported configurations are reported separately from supported-path evidence. Unobserved states are explicitly marked, with nondestructive evidence or an approved limitation.
- Opt-in checks are disabled in ordinary test runs, including before service initialization or asset installation.
- Framework quirks remain in test-only Apple code. Record any necessary future shared or bundle changes and why.
- Record OS/hardware/toolchain, sample/configuration, measured timings and quality tradeoffs concisely in the spec. Keep reproducible synthetic cases; avoid ceremony and exhaustive permutations.
- Independent review and focused closure pass. Discovery of an unsupported feature is valid spike evidence but must be carried to the final decision gate, never presented as feature-complete support.

### Targeted verification

On a Mac with the repository's Swift 6.2 toolchain, add tests whose names include `AppleVoiceSpike`. Run:

```bash
swift test --disable-xctest --filter AppleVoiceSpike
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleVoiceSpike
git diff --check
```

The first command confirms the opt-in tests skip without starting services. The second runs live checks; recording-based tests additionally need ECHOTYPE_FIXTURE_WAV set to an existing local WAV. Add exact recording/comparison and signed-host commands to your handoff once the candidate exists, without literal secret values. If Mac execution is unavailable, prepare the candidate and block at its Mac gate. Do not treat compilation elsewhere as live validation.

## Implementation handoff

- Base commit: `db08e7a` on `spike/apple-on-device-provider`. Complete recovery ownership audit attributed the S2 candidate to the feature specification, this packet, plan, `AppleVoiceSpike.swift` and `Integration/AppleVoice/AppleSpikeSpeechStream.swift`. Recovery preserved the helper and general calibration, clarified its calibration-only comment and refreshed the handoff. Independent review and fresh closure passed after one documentation remediation for Required R1. S2 is accepted. Production, shared contracts and other streams are unchanged.
- Environment: MacBookPro18,3, Apple M1 Pro, 16 GB RAM, arm64, macOS 27.2 build 26B5091g, Swift 6.4, SDK 27.0. The fresh inventory again reports Apple Intelligence available and 182 voices. Daniel Enhanced, Samantha Compact and Zoe Premium all synthesize mono noninterleaved Float32 at 22,050 Hz, with callbacks at most 256 frames. Siri is absent. No host, prompt, asset installation/removal, Settings change, network change or agent audio playback was used.
- Preserved diagnosis: the inherited helper once treated the first empty PCM callback as EOF. Aidan correctly identified omitted latter-half content, rather than faster speech. Silent diagnosis observed further PCM after that callback, adding 274,398 Daniel, 264,243 Samantha and 258,208 Zoe frames. The corrected helper retains `AVSpeechSynthesizerDelegate.didFinish` completion after queued PCM callbacks. Empty callbacks only record offsets. Generated/pulled counts, all submitted scalars and no late comparison tail are checked. The writer wrote all delivered samples correctly.
- Rejected boundary and correction: Aidan preferred continuous speech and rejected the pause after "We are comparing the". The candidate now uses Foundation sentence enumeration to choose the last complete sentence boundary within the existing 250-scalar bound. It submits another utterance only after delegate completion and all PCM is pulled. If a sentence alone exceeds 250 scalars, it must still break at a word, or at the hard bound if there is no whitespace. This preserves bounded read-ahead, but arbitrary oversized-sentence prosody remains unmeasured. No abbreviation rules, tokenization dependency, pause timer or growing utterance queue was added.
- The identical 448-scalar paragraph now splits into 224 + 224 scalars, after "the next words should still make sense." The complete fourth sentence beginning "We are comparing the rhythm" stays together. Daniel's continuous and sentence-aware outputs both contain 566,698 frames, 25.700590 s; Samantha's both contain 544,745 frames, 24.704989 s; Zoe's both contain 529,736 frames, 24.024308 s. First-buffer continuous/sentence-aware times were Daniel 247/275 ms, Samantha 548/530 ms and Zoe 717/731 ms. Extracted WAV PCM is byte-identical within each pair. SHA256 results are in `/tmp/echotype-s2-sentence-final-pcm.log`. This establishes identical audio for this paragraph, including removal of the rejected inserted pause. It is not a word transcript or a guarantee for other text. `afinfo` independently confirms the Zoe sentence-aware WAV's mono Float32 format and 529,736 frames.
- Speed investigation: a temporary calibration version silently measured AV rates `[0.1, 0.15, 0.2, 0.3, 0.4, 0.45, 0.5, 0.52, 0.54, 0.56, 0.58, 0.6]` for all three installed voices using the same 104-scalar sentence. Raw output is `/tmp/echotype-s2-rate-grid.log`. The final candidate replaces that grid with fixed voice-specific anchors and measurements at eight slider values. There is no runtime calibration system. The measured calibration exploration covers 0.7...1.5, with piecewise interpolation through the table below. It does not establish a usable range. Aidan rejected the offered 0.7x/1.5x samples and accepted 1x. Samantha has slow-rate plateaus: raw AV rates 0.15 and 0.2 both give 8.174 s; 0.4 and 0.45 both give 6.427 s. Its nearest measured slow anchor, 0.15, gives about 0.715x rather than exact 0.7x. Treat the slider as an approximate duration multiplier, not a guarantee for arbitrary text.

| Voice | AV rate at 0.7x | 0.85x | 1x | 1.25x | 1.5x |
|---|---|---|---|---|---|
| Daniel Enhanced | 0.1578 | 0.3297 | 0.5 | 0.5420 | 0.5860 |
| Samantha Compact | 0.1500 | 0.3216 | 0.5 | 0.5427 | 0.5894 |
| Zoe Premium | 0.1626 | 0.3426 | 0.5 | 0.5414 | 0.5849 |

Actual relative speeds below are default-rate duration divided by measured duration. These are silent measurements, not listening judgments.

| Requested slider value | Daniel | Samantha | Zoe |
|---|---|---|---|
| 0.7 | 0.703 | 0.715 | 0.702 |
| 0.85 | 0.850 | 0.835 | 0.864 |
| 0.925 | 0.934 | 0.910 | 0.929 |
| 1 | 1 | 1 | 1 |
| 1.1 | 1.080 | 1.079 | 1.097 |
| 1.25 | 1.244 | 1.235 | 1.242 |
| 1.4 | 1.402 | 1.427 | 1.403 |
| 1.5 | 1.493 | 1.503 | 1.490 |

- Independent text check: the 448-scalar continuous paragraph at requested 0.7/1/1.5 produced Daniel 36.718/25.701/17.098 s, actual 0.700/1/1.503x; Samantha 34.558/24.705/16.417 s, actual 0.715/1/1.505x; Zoe 34.338/24.024/16.035 s, actual 0.700/1/1.498x. Slow/normal/fast paragraph WAVs and the short sentence at every measured speed are exported to `/tmp/echotype-apple-voice-sentence-final`. Aidan judged only the offered 1x sample usable; the 0.7x/1.5x endpoints are rejected listening evidence.
- Pause/resume: the 1,260-scalar reading submitted one 210-scalar utterance before pausing pulls. At both two and four seconds it had 1,103 callbacks and 282,060 generated frames. Peak unread PCM was 281,856 samples, 1,127,424 payload bytes. Peak retained PCM count across the full reading was 282,060 samples, 1,128,240 payload bytes. Resume delivered all 1,692,360 generated frames across six completed utterances, with all input scalars submitted and at most 100 ms per pull. Counts describe Float32 payload, not Array capacity or all framework allocations. A confirmed pending pull threw on repeated cancellation in 0.116 ms; synthesis stopped and no accepted callbacks followed during the 200 ms check. A new reading completed with a 253 ms first buffer. The 60,000-scalar punctuation-free request still accepts its first bounded pull, with full drain explicitly unmeasured.
- Memory observation: `/bin/ps -o rss= -p <test-process-pid>` measured RSS as 75,392 KiB before first pull, 75,440 KiB at two seconds paused, 75,456 KiB at four seconds, and 75,488 KiB after drain. The two-second paused interval grew by 16 KiB while callback/frame counts stayed fixed. A prior run gave 74,576/74,592 KiB at two/four seconds. This is a short process-level observation in a warmed test process. It includes the tests and framework allocations in that process, excludes separate synthesis services, and does not prove isolated framework memory or long-duration behavior. No destructive memory experiment was used.
- Caller compatibility: inspection confirms MCP requests enter `SpeechAdmission.receive`, then `DictationController.speak`, then the same Reader, with replacement stopping the earlier reading. Existing `MCPDeliveryTests` and `SpeechAdmissionTests` checks ran successfully, eight checks in three suites in 0.012 s, using fake dependencies. They establish existing delivery/admission behavior, including replacement during startup and pause. They do not run the Apple stream through the signed app or an external MCP connection. Actual Apple MCP wiring would require production changes, so none was attempted. Reader accepts the observed dynamic rate and chunk shape; SpeechPlayer limits its queue to half a second. No additional shared or bundle change emerged from this experiment.
- Lasting user decisions: Aidan previously preferred the short 1x sample, supplied a five-test pass in 15.547 s in response to the network-disconnected command, identified truncated continuous audio and downloaded Zoe Premium himself. Offline state is user-reported, not agent-observed. His latest answer rejects the old mid-sentence boundary, asks for a practical speed slider, defers alternate locales and full 60,000-character completion, does not require signed Reader evidence, and waives formal same-text xAI comparison. His judgment is that xAI sounds far superior but a free local option remains valuable. His follow-up selects Zoe as the provisional Apple default. Only 1x among the offered 0.7x/1x/1.5x samples is usable. His usual xAI speed is 1.1x, but his latest steering says he is happy with 1x for this spike and will tweak a slider during future implementation. No further 1.1x investigation is required. This does not authorize production wiring or asset changes. Unobserved prosody, asset failure/removal and isolated service memory remain evidence bounds for later validation, not missing spike criteria or waived support.
- Availability/setup: the fresh inventory and nil invalid-id lookup still establish missing-id detection and same-language fallback without changing the saved choice. Previously absent Zoe now resolves and synthesizes after Aidan's download. Public SDK declarations offer inventory, lookup and voices-change notification, but no system-voice download/progress operation. Future app setup remains user-managed Read & Speak settings guidance and inventory refresh. Download failure, interrupted download, asset removal and removal during synthesis were not induced. Those states remain unobserved. Agents changed no assets or settings. Existing French/Chinese fallback checks still pass, but wider locale calibration is deferred by Aidan.
- Verification: six disabled checks skipped before service initialization. Six silent live checks passed in 41.378 s. The candidate verifies generated/pulled equality, scalar preservation, constant sample rate, valid Float32 samples, completed utterances and each segment's hard bound. `git diff --check` passed. Raw logs, WAVs and the older diagnosis remain outside the repository. The simplification pass removed the inherited repeated Daniel raw-rate loops, reused one paragraph and one installed-voice selection for comparisons/calibration, and retained one bounded synthesis helper. No general calibration machinery, signed host, production wiring or extra asset-management layer was added.
- Latest recovery verification: six ordinary checks skipped before service initialization in 0.001 s; six silent live checks passed in 40.850 s. Inventory remains 182 voices with Zoe present and Siri absent. Zoe continuous and sentence-aware paragraph durations both remain 24.024308 s, 529,736 frames, with first buffers at 701/710 ms; generated/pulled and scalar checks pass. Fresh pause/resume again stayed at 1,103 callbacks and 282,060 generated frames at two/four seconds and drained all 1,692,360 frames. Process RSS was 73,824/73,872/73,888/73,904 KiB before first pull, at two/four seconds paused, and after drain. Pending cancellation took 0.087 ms, restart first buffer 267 ms. Prior exported Zoe WAVs still match with `cmp`; `afinfo` confirms mono Float32 22,050 Hz and the recorded duration. This rerun adds no quality judgment or isolated service-memory evidence. Read-only Reader/MCP inspection confirms the recorded caller path and half-second player queue. The simplification pass retained the existing bounded helper and static exploration, removed the new 1.1x-only test after Aidan's steering, and added no production machinery.
- Lead gate triage: Aidan's latest clarification accepts Zoe at 1x for this spike and defers slider tuning to future implementation. No 1.1x listening or repeated endpoint decision is required. Generated/pulled counts, delegate completion and byte-identical continuous/sentence-aware paragraph PCM supply nondestructive completeness evidence. The packet asks for missing-voice detection and peak buffered audio, already measured through before/after Zoe lookup, invalid-id fallback and paused PCM counts. It does not require inducing voice download failures/removal or measuring isolated synthesis-service memory. Before production claims, listen to oversized-sentence splits, check inventory refresh/fallback and recovery after failed/interrupted downloads and voice removal in an authorized setup, and observe synthesis-service memory through a longer paused/drained/cancelled reading. These remain evidence bounds. Oversized sentences necessarily split within the hard bound; their prosody remains a stated quality limitation, not missing streaming functionality. Lower voice quality is explicitly acceptable. This triage grants no blanket quality waiver or asset-change authorization. Independent review accepted the evidence and criterion interpretation, with Required R1 for stale documentation.

Exact silent commands executed from the repository root:

```bash
# Temporary raw-grid calibration version, before fixed anchor selection.
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter calibrationAppleVoiceSpike > /tmp/echotype-s2-rate-grid.log 2>&1
# Latest recovery, without exports or playback.
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleVoiceSpike > /tmp/echotype-s2-zoe-decision-live.log 2>&1
swift test --disable-xctest --filter AppleVoiceSpike > /tmp/echotype-s2-zoe-decision-disabled.log 2>&1
# Previous sentence-aware candidate and exports.
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_VOICE_SAMPLE_DIR=/tmp/echotype-apple-voice-sentence-final swift test --disable-xctest --filter AppleVoiceSpike > /tmp/echotype-s2-sentence-final-live.log 2>&1
swift test --disable-xctest --filter AppleVoiceSpike > /tmp/echotype-s2-sentence-final-disabled.log 2>&1
swift test --disable-xctest --filter 'MCPDeliveryTests|SpeechAdmissionTests' > /tmp/echotype-s2-mcp-compatibility.log 2>&1
afinfo /tmp/echotype-apple-voice-sentence-final/com.apple.voice.premium.en-US.Zoe-paragraph-sentence-aware-rate-0.5.wav
git diff --check
```

The continuous/sentence-aware PCM equality can also be checked with these exact commands. Full WAV files match in this run, stronger than matching only their audio data:

```bash
cmp /tmp/echotype-apple-voice-sentence-final/com.apple.voice.enhanced.en-GB.Daniel-paragraph-continuous-rate-0.5.wav /tmp/echotype-apple-voice-sentence-final/com.apple.voice.enhanced.en-GB.Daniel-paragraph-sentence-aware-rate-0.5.wav
cmp /tmp/echotype-apple-voice-sentence-final/com.apple.voice.compact.en-US.Samantha-paragraph-continuous-rate-0.5.wav /tmp/echotype-apple-voice-sentence-final/com.apple.voice.compact.en-US.Samantha-paragraph-sentence-aware-rate-0.5.wav
cmp /tmp/echotype-apple-voice-sentence-final/com.apple.voice.premium.en-US.Zoe-paragraph-continuous-rate-0.5.wav /tmp/echotype-apple-voice-sentence-final/com.apple.voice.premium.en-US.Zoe-paragraph-sentence-aware-rate-0.5.wav
```

## External validation

- Gate: Mac measurements before independent review. Passed for spike review on 2026-10-02. Six live checks passed on Aidan's configured Mac, with missing-id/post-install lookup, language fallback, bounded paused PCM, complete drain, pending cancellation/restart and byte-identical paragraph comparison. Aidan chooses Zoe provisionally and is happy with 1x for the spike. Slider tuning is deferred to future implementation. Offline execution is user-reported, as recorded above.
- Candidate: uncommitted S2 diff against `db08e7a`. Delegate completion preserves the formerly omitted PCM tail. Sentence-aware default-rate paragraph output is byte-identical to continuous for all three voices. Static rate mapping remains exploratory; 0.7x and 1.5x are rejected usability endpoints.
- Evidence bounds: oversized-sentence word-split prosody, download failures/interruption, removal during synthesis and isolated synthesis-service memory are unobserved. Nondestructive missing-id/post-download observations and fixed paused PCM counts answer the required availability/buffering questions. These bounds are carried to the final decision and the concrete production checks in the handoff, without claiming support or a user waiver.
- Reproduction: exact silent commands and `cmp` checks are in the handoff. No fixture WAV, xAI key or signed host is needed. Old options-repeat exports omit content and content-final exports contain the rejected boundary; sentence-final exports contain the corrected paragraph. No further playback is requested.

## Independent review

- Reviewer: fresh independent review on 2026-10-02 of the complete S2 candidate against `db08e7a`, including both untracked test files, the specification, packet and plan. Read the workflow, adapter decision, provider contracts and Reader, SpeechPlayer and MCP admission/controller code. Applied the unslop skill to this record. No implementation files changed.
- Verdict: experiment and Mac gate triage pass. No implementation defect or containment violation found. One required documentation correction remains before acceptance.
- Required R1: synchronize the S2 results, plan escalation/drift and packet resolution/closure status with the latest recorded decisions and review phase. The specification still says no voice preference was supplied, slow/fast usability needs Aidan, and unresolved judgments block independent review. The plan still retains a Blocked S2-limitations request and superseded 1.1x work. Those statements contradict the recorded Zoe preference, accepted 1x and future slider tuning. Preserve the rejected extreme rates and unobserved states as evidence bounds; remove the resolved request without implying that Aidan approved destructive experiments or those states were measured.
- Optional: later production validation should cover oversized-sentence split prosody, system voice download/removal failures and synthesis-service memory where relevant. These were not required destructive experiments in the frozen S2 packet. Missing-id lookup before/after Zoe installation, language fallback and paused PCM payload counts answer its availability/buffering questions. No exhaustive state suite, signed host or additional 1.1x experiment is needed for this spike.
- Question: none. Aidan's latest clarification settles the current speed/listening decision. Only 1x is accepted among the offered samples; the static mapping demonstrates duration control, not a proven usable 0.7...1.5 range.
- Evidence assessment: one bounded utterance prevents unlimited text read-ahead while pulls pause; delegate completion fixes the demonstrated intermediate-empty-buffer truncation. The 250-scalar limit still splits oversized sentences, an explicit quality limitation permitted by the fallback requirement. Generated/pulled equality and scalar submission alone do not transcribe words, but all three exported continuous/sentence-aware WAV pairs independently match with `cmp`. This supports completeness and removal of the rejected boundary for the measured paragraph without claiming general prosody equivalence. Current constant-rate mono Float32 buffers fit Reader and SpeechPlayer. MCP inspection and fake delivery tests establish caller compatibility, not signed Apple integration. Offline execution remains user-reported.
- Independent verification: six ordinary checks skipped in 0.001 s before service initialization. A fresh silent lifecycle check passed in 6.717 s. It again submitted one 210-scalar segment while paused, held 1,103 callbacks and 282,060 generated frames at two/four seconds, then delivered all 1,692,360 frames across six segments. Pending repeated cancellation threw in 0.125 ms, stopped synthesis, and restart completed. Peak unread/retained PCM payload remained 1,127,424/1,128,240 bytes. Fresh lifecycle-only process RSS was 46,992 KiB before first pull, 61,168/61,104 KiB paused and 61,328 KiB drained, demonstrating why these process observations are not isolated service-memory measurements. Eight existing MCP/admission checks passed. `git diff --check` and the three `cmp` checks passed. Reviewed the lead's six-check live log, which passed in 40.850 s. Fresh logs are `/tmp/echotype-s2-independent-disabled.log`, `/tmp/echotype-s2-independent-lifecycle.log` and `/tmp/echotype-s2-independent-mcp.log`; no audio playback, network/settings change or asset operation occurred.

## Resolution

- Recovery: preserved Aidan's lasting decisions and reused the corrected delegate-completion candidate. The implementation pass replaced the rejected mid-sentence break with bounded sentence-aware segmentation, measured static voice-specific slider mappings and observed short paused-process RSS. No production behavior changed.
- Simplification: one bounded helper, one shared synthetic paragraph and installed-voice selection. Removed repeated raw-rate calibration loops after recording evidence. No timer, general calibration machinery, signed host or asset-management layer added. The 250-scalar hard bound still requires word splits in oversized sentences, explicitly unmeasured for prosody.
- Verification: six disabled checks skipped, six silent live checks passed in 41.378 s, eight existing MCP/admission checks passed. Three comparison WAV pairs are byte-identical. Lead inspected the complete owned candidate and logs; `git diff --check` passed. Independent review passed the experiments and Mac gate triage with Required R1 for documentation. Fresh closure passed Required R1 and found no remaining blocker. S2 accepted after one documentation remediation.
- Required R1 accepted and remedied: synchronized the specification, current handoff, gate, plan and review phase with Zoe as provisional Apple default, accepted 1x and future slider tuning. Removed the resolved S2-limitations escalation and superseded playback/1.1x requests. Static 0.7...1.5 mapping remains exploration; both offered endpoints remain rejected. The frozen task packet and independent review are unchanged.
- Optional observations retained: oversized-sentence prosody, failed/interrupted downloads/removal and isolated synthesis-service memory have concrete later production checks in the handoff and results. They are unobserved evidence bounds, not claimed support or user-approved waivers. No additional experiment or code change was needed.

## Closure review

- Reviewer: fresh focused closure on 2026-10-02 against `db08e7a`. Read the workflow, packet, plan, feature specification, adapter decision and provider contracts. Inspected the complete owned diff, both untracked test files and the relevant Reader, SpeechPlayer and MCP/controller path. Applied the unslop skill. Only this section changed; no implementation edit or commit.
- Verdict: pass. Required R1 is resolved. The specification, handoff, Mac gate and plan now agree on Zoe as the provisional Apple default, accepted 1x for this spike and slider tuning during future implementation. Offered 0.7x/1.5x endpoints remain rejected; no further 1.1x experiment is required. The resolved S2-limitations request is removed, with the lasting decision retained. Historical independent-review findings remain intact; acceptance status updates belong to the lead.
- Evidence bounds remain accurate. Missing-id lookup before/after Zoe installation, language fallback and fixed paused PCM counts answer the required availability/buffering questions. Download failure/interruption/removal, oversized-sentence split prosody and isolated synthesis-service memory remain unobserved, with concrete later validation. They are neither claimed support nor user-approved waivers. Offline execution remains user-reported, and MCP fake checks remain caller compatibility evidence. Production behavior and shared contracts are untouched.
- Verification: a fresh ordinary run skipped all six checks before service initialization in 0.001 s, recorded in `/tmp/echotype-s2-closure-disabled.log`. Independently compared all three exported continuous/sentence-aware WAV pairs; each is byte-identical. Reviewed the six-check live log, the independent pending-cancellation/drain/restart log and the eight-check MCP/admission log. They support the recorded results. `git diff --check` passed. The documentation-only remedy did not require another live synthesis or listening run.
- Remaining required findings: none. No release-blocking implementation or containment defect found. The recorded evidence bounds carry forward to the final decision gate; they do not block S2 acceptance.
