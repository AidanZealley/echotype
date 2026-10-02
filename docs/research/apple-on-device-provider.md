# Apple on-device provider research

Accepted measured-feasibility investigation, 2026-10-02. The [product specification](../specs/apple-on-device-provider.md) is the source of requirements and approved policies. This document holds supporting evidence, reproducible experiments and remaining verification. All three services are technically feasible on the configured Mac within the existing operation contracts. Availability, specified as readiness, is the only shared addition the spike justified. Voice choices, language handling and other policies recorded here were later revised in the specification, which governs implementation.

Aidan approved completing the investigation and deferred cleanup tuning to real use after implementation. The separate name-correction and preservation failures remain quality risks. The 840-word repetitive fixture is ambiguous stress evidence, not evidence of ordinary long-dictation failure.

## Environment and provenance

Measurements ran on Aidan's Mac on 2026-10-01 and 2026-10-02: MacBookPro18,3, Apple M1 Pro with eight cores, 16 GB RAM, arm64, macOS 27.2 build 26B5091g, Apple Swift 6.4, macOS SDK 27.0 and locale `en_GB`. Apple Intelligence and `SystemLanguageModel.default` reported available. The original packets named Swift 6.2; measurements used the installed toolchain above.

The investigation began on `spike/apple-on-device-provider` at `51083b55b39afd49937b2eddf466d731d7993b10`. S2 used base `db08e7a`; S3 used `567a959a2353e5e8632fd5a2136421eb627a9ce6`. Whole-spike review examined `73090b8` plus the combined matrix and reconciled availability policy. Git history retains the completed execution packets and review records. Their stale execution instructions have been retired.

Experiments run directly in SwiftPM and remain test-only. No production, package, registry, signing, deployment or existing xAI behavior changed. No signed experimental host was needed. Raw personal audio, synthetic exports and logs remain outside the repository. No xAI credential was available, so there is no same-recording accuracy/latency comparison. S2's formal same-text xAI comparison was waived by Aidan.

## Live transcription

Measured on 2026-10-01 through the real SessionMachine. Recordings stream as real-time-paced 100 ms chunks. Initial synthetic input contains 16.568 seconds of `say` speech plus two three-second pauses. Human recovery used the supplied 27.993-second recording, its fresh 34.993-second pause variant and a five-second prefix.

| Question | Evidence and interpretation |
|---|---|
| Transcript mapping | Volatile results rewrite the current segment and sometimes contain partial words. Final results append segments, including their leading whitespace. The test adapter maps final segments to committed, keeps utterance empty and maps volatile text to provisional. SessionMachine's committed-prefix checks passed. Final segment ranges differ from preceding volatile ranges; treating every result as a new segment would duplicate text. |
| Utterances and speech | Finalization occurred at sentence boundaries while more audio was coming. It does not alone establish an utterance boundary. The final spoken sentence remained provisional through three seconds of trailing silence and resolved only after finish. Paired SpeechDetector emitted no results in these runs. Recognition text supplies speech evidence and avoids the observed ten-second no-speech cancellation. With a two-second test silence timeout, SessionMachine paused and resumed across the recorded gap. Human pause checks also produced two paused snapshots per run and returned to listening. True acoustic onset and room silence remain unmeasured. |
| Input | The advertised formats were 8 kHz and 16 kHz mono Int16. The app's 16 kHz Int16 was accepted directly in AVAudioPCMBuffer, with explicit buffer timestamps. No Apple resampler was needed on this SDK. Other OS/SDK behavior is unmeasured. |
| Latency and tail | First word arrived about 1.06 s after adapter launch. On the final synthetic run, final tail arrived 65 to 71 ms after finish and stop-to-outcome took 109 to 117 ms. SessionMachine inserted the complete tail in both context variants. Human original first word was 1.960 to 1.987 s, final tail 60 to 73 ms and stop-to-outcome 144 to 151 ms. With fresh pauses, first word was 1.974 to 1.997 s, tail 73 to 75 ms and stop-to-outcome 152 to 154 ms. These are Apple-only checks; the earlier xAI fixture was not recovered. |
| Accuracy and keyterms | Plain words and the final sentence survived. Both context variants rendered EchoType as two words, Zustand as "zust and", and TanStack as two words. The terms did not fix those synthetic pronunciations. TranscriptionRequest supplied built-in EchoType followed by saved terms to AnalysisContext, and framework readback confirmed them. Lists of 1, 100 and 1000 strings were accepted and read back; this does not establish their recognition effect or the usable maximum. The four full human runs returned identical normalized 43-word content, with punctuation differences; context did not change words. The supplied sample has no saved jargon and no independent reference transcript, so it establishes neither jargon improvement nor a word-error rate. These transport measurements support the provisional cap in the specification; human jargon evidence is still needed. |
| Assets and setup | Initially English locales were installed. `status` reported supported even when the English installation request was nil; query results changed to installed after setup queries. A missing fr-FR request existed. Its download completed in 8.995 s despite task cancellation at 100 ms, with 8.891 s cancellation-to-join. A later request was nil. Querying requests also left en_GB/fr_FR reserved; French regional locales remain installed. No failed download or retry was observed. |
| Installed-model readiness | Start returned in 0.09 to 2.18 ms while a worker prepared the analyzer before ready. Preparation took 82 to 125 ms on the first load in a fresh test process and 37 to 51 ms subsequently, within the five-second readiness timeout. System caches may already be warm; genuinely cold loading is unproven. The nine-second download exceeded the existing readiness timeout, which supports setup before capture. |
| Lifecycle | Immediate finish requested around 13 ms before readiness resolved to empty completion. Loading cancellation requested after 10 ms joined by 38 to 39 ms from launch. Repeated close joined normally. Five-second human prefixes preserved final text, with tail 90 to 92 ms and stop-to-outcome 97 to 99 ms. Active cancellation after five seconds joined in 1.77 ms with no insertion. Three seconds of zero PCM produced no text and Speech error Code 1 RecogRejected at finish. The candidate exposes that failure; a future empty-silence policy must validate real-room silence rather than broadly swallowing Code 1. |
| Permissions | File input completed without a prompt or authorization request; Speech authorization remained notDetermined. SwiftPM needed no signed host. The production bundle currently has microphone usage text and audio-input entitlement, with no speech usage text. These experiments do not establish microphone or signed-app permissions, so no bundle change is proposed yet. |
| Language and availability | 45 regional locales were advertised. Exact en-GB/en-US matched their regions; de matched de_DE, ja matched ja_JP, zh-Hant matched zh_TW and xx-ZZ was unsupported. Bare en varied between en_GB, en_SG and en_US across processes; bare fr varied between fr_CA/fr_CH. Settings accepts arbitrary BCP-47 strings; equivalent supported matching is feasible, but bare-tag ordering is unstable. Unsupported hardware was not present; isAvailable was true. Installed lists, status and request existence differ, so status alone cannot decide whether setup is needed. |

### Recording provenance and caller fit

Aidan supplied `orig_127389__acclivity__thetimehascome.wav` as an external attachment at `/Users/aidanzealley/.t3/userdata/attachments/93f56caa-32f4-4add-81b5-02ace679998e-c935c317-5da4-4f1b-a30e-d82591437b6a-wav.wav`. It contains 4,937,944 bytes, 27.993 seconds, 44.1 kHz stereo PCM16; SHA-256 `a4056ff0022e9d602c7128ebf0253328e57f8ad4f2fce8a6f3228384016ed483`. Existing WAVRecording and AudioConverter supply 16 kHz mono input. The attachment is human speech, with no independent reference transcript or saved jargon.

The earlier public-corpus fixture documented at commit `bb8b43be6eed354936b6958a6dcda0e3aa12be8d`, `~/echotype-fixtures/sample-with-pauses.wav`, was absent from the repository, ignored files, other registered worktree and reachable git objects. The supplied attachment is not proof of recovering that fixture. The fresh `/tmp/echotype-s1-human/with-pauses.wav` preserves its samples and adds 3.5-second zero-filled pauses after original times 6 and 12 seconds. `/tmp/echotype-s1-human/five-seconds.wav` contains its original five-second prefix. Source audio was unchanged.

DictationOperation starts capture before opening the adapter; the readiness timeout begins after `start` returns. The experiment launches preparation separately and returns promptly. Test commits five seconds after its initial snapshot and bypasses cleanup/insertion. Human prefix finalization measures the compatible adapter path, while signed Test remains unimplemented. Normal finish drains capture before closing input. No shared SessionMachine change was needed.

Initially English assets were installed with no reservations. Installation-request queries and the explicit fr-FR experiment left `en_GB`/`fr_FR` reserved and installed `fr_BE`, `fr_CA`, `fr_CH`, `fr_FR`, without an explicit reserve/release call. Request creation therefore has side effects even when no download is needed. Recovery changed no assets or settings.

## Read aloud

Measured silently on 2026-10-02. Six live checks passed in 41.378 s, with a recovery pass in 40.850 s. No agent playback, permission prompt, signed host, network change or asset/settings change was used. Aidan installed Zoe himself and judged xAI far superior while valuing the free local option. His listening decision accepts Zoe at 1x; slider tuning belongs to implementation.

| Question | Evidence and interpretation |
|---|---|
| Siri and alternatives | Inventory has 182 voices after Aidan installed Zoe Premium, up from 181. Siri remains absent and its historical identifier returns nil. [Apple's WWDC20 explanation](https://developer.apple.com/videos/play/wwdc2020/10022/) states Siri voices are unavailable through this API. Installed candidates are Daniel Enhanced, `com.apple.voice.enhanced.en-GB.Daniel`; Samantha Compact, `com.apple.voice.compact.en-US.Samantha`; and Zoe Premium, `com.apple.voice.premium.en-US.Zoe`. All synthesize. Aidan prefers continuous speech, found the earlier 1x sample better and judges xAI far superior, while valuing a free local option. Aidan chose Zoe as the provisional Apple default. Lower quality does not block feasibility. |
| Format and latency | All three candidates emit mono noninterleaved Float32 at 22,050 Hz, with callbacks at most 256 frames, about 11.6 ms. The test helper copies Float32, averages channels, checks a constant sample rate and delivers at most 100 ms per pull. Every delivered sample was finite and within -1...1. Paragraph first-buffer continuous/sentence-aware times were Daniel 247/275 ms, Samantha 548/530 ms and Zoe 717/731 ms. Earlier French/Traditional Chinese checks used the same format. Other PCM formats and actual stereo conversion remain unobserved. The observed format fits Reader without a shared change; Aidan asked the agent to choose a compatible format. |
| Speed slider | Exploratory duration mapping over 0.7...1.5 uses fixed voice-specific rate anchors, recorded below. At requested .7/.85/.925/1/1.1/1.25/1.4/1.5, measured short-sentence speeds stay within about 2.2% of target. Daniel's actual endpoints were .703/1.493, Samantha's .715/1.503 and Zoe's .702/1.490. A separate paragraph gives .700/1.503, .715/1.505 and .700/1.498. Samantha's slow-rate plateaus prevent exact continuous duration matching. No runtime calibration system is proposed. Silent duration evidence demonstrates rate control, not a usable 0.7...1.5 range. Aidan rejected the offered 0.7x and 1.5x samples and accepted 1x for the spike. He will tune the future slider during implementation; no 1.1x sample is required. |
| Missing voices and setup | Before Aidan's download Zoe lookup returned nil; afterwards it resolves and synthesizes. Invalid ids still return nil. Enumeration/lookup therefore support unavailable-id detection and installed same-language fallback without replacing saved ids. Public SDK declarations provide lookup, inventory and voices-change notification, without a system-voice download/progress API. Future setup is user-managed [Read & Speak settings](https://support.apple.com/guide/mac-help/change-the-voice-your-mac-uses-to-speak-text-mchlp2290/mac), guidance and inventory refresh. Download failure, interrupted downloads and removal during synthesis were not induced. Aidan's earlier five-test pass in response to the network-disconnected command is reported offline evidence, not agent-observed networking. |
| Bounded synthesis and lifecycle | One utterance of at most 250 Unicode scalars is submitted; another starts only after delegate completion and PCM consumption. Sentence endings are preferred. The 1,260-scalar reading paused after its first pull submitted only 210 scalars. At two/four seconds it stayed at 1,103 callbacks and 282,060 frames. Peak unread payload was 1,127,424 bytes; peak retained PCM payload 1,128,240 bytes. Resume delivered all 1,692,360 generated frames across six utterances, with every scalar submitted. A confirmed pending pull threw on repeated cancellation in .116 ms; synthesis stopped, no accepted callbacks followed over 200 ms, and another reading completed. Process-level memory observations and their limits are recorded below. |
| Language and text limit | Saved Daniel remains for compatible en/en-US. French and zh-Hant fallbacks synthesize with Thomas and Meijia without changing saved Daniel. Missing-id fallback now chooses Zoe for bare en/en-US; xx-ZZ is unavailable. The experiment uses a proposed 60,000-scalar service cap with bounded internal utterances. Its first pull works; full drain is unmeasured and Aidan explicitly deferred it. Wider locale calibration is also deferred. Sentences longer than 250 scalars still require a word/hard split, whose prosody is unmeasured. |

### Completion, prosody and rate evidence

The initial helper treated the first zero-frame callback as EOF, omitting latter-half content. Further callbacks added 274,398 Daniel, 264,243 Samantha and 258,208 Zoe frames. The corrected helper finishes on `AVSpeechSynthesizerDelegate.didFinish` after copying preceding PCM callbacks; zero-frame callbacks only record offsets.

Aidan rejected a pause after "We are comparing the". Foundation sentence enumeration now chooses the last complete sentence within the 250-scalar bound. The 448-scalar paragraph splits into 224 + 224 scalars after "the next words should still make sense." Oversized sentences still require word or hard-bound splits. No pause timer, abbreviation rules or growing utterance queue was added.

Continuous and sentence-aware paragraph audio match byte-for-byte for Daniel, Samantha and Zoe. Their frame counts/durations are 566,698/25.700590 s, 544,745/24.704989 s and 529,736/24.024308 s. This establishes completeness and removal of the rejected boundary for this paragraph, not general word accuracy or prosody. `afinfo` confirms Zoe's mono Float32 22,050 Hz output. PCM hashes were recorded in `/tmp/echotype-s2-sentence-final-pcm.log`.

A temporary raw-rate grid measured `[0.1, 0.15, 0.2, 0.3, 0.4, 0.45, 0.5, 0.52, 0.54, 0.56, 0.58, 0.6]` against one 104-scalar sentence. The spike test used fixed anchors and interpolation, with no runtime calibration system. The following table records those anchors. The duration ratios below record the eight-value short-sentence comparison.

| Voice | AV rate at 0.7x | 0.85x | 1x | 1.25x | 1.5x |
|---|---|---|---|---|---|
| Daniel Enhanced | 0.1578 | 0.3297 | 0.5 | 0.5420 | 0.5860 |
| Samantha Compact | 0.1500 | 0.3216 | 0.5 | 0.5427 | 0.5894 |
| Zoe Premium | 0.1626 | 0.3426 | 0.5 | 0.5414 | 0.5849 |

Actual relative speed is default-rate duration divided by measured duration.

| Requested multiplier | Daniel | Samantha | Zoe |
|---|---|---|---|
| 0.7 | 0.703 | 0.715 | 0.702 |
| 0.85 | 0.850 | 0.835 | 0.864 |
| 0.925 | 0.934 | 0.910 | 0.929 |
| 1 | 1 | 1 | 1 |
| 1.1 | 1.080 | 1.079 | 1.097 |
| 1.25 | 1.244 | 1.235 | 1.242 |
| 1.4 | 1.402 | 1.427 | 1.403 |
| 1.5 | 1.493 | 1.503 | 1.490 |

Samantha's raw rates .15/.2 both give 8.174 s and .4/.45 both give 6.427 s. Its slow anchor is about .715x. On an independent 448-scalar paragraph, requested .7/1/1.5 produced actual Daniel .700/1/1.503, Samantha .715/1/1.505 and Zoe .700/1/1.498. Duration ratios are approximate control evidence. Aidan rejected the offered .7x/1.5x audio; no additional 1.1x sample was required.

Paused-reading process RSS was 75,392 KiB before first pull, 75,440/75,456 KiB after two/four seconds paused and 75,488 KiB after drain. Recovery measured 73,824/73,872/73,888/73,904 KiB with unchanged callback/frame counts while paused. These short warmed-process observations exclude separate synthesis services and do not establish isolated service memory or long-duration bounds. Recovery cancellation took .087 ms; restart first buffer arrived at 267 ms.

MCP requests reach SpeechAdmission, DictationController and the same Reader; replacement stops the earlier reading. Reader accepts the dynamic rate/chunk shape, and SpeechPlayer queues at most half a second. Eight existing fake delivery/admission checks passed in .012 s, including startup/pause replacement. These establish caller compatibility, not signed Apple or external MCP integration.

## Cleanup

Measured on 2026-10-02 with a 4,096-token available model. Each request uses a fresh LanguageModelSession, exact Reviser.prompt, greedy generation and unchanged default framework protections. Production Reviser owns windows, validation and the final deadline. Inputs are synthetic English text. Recovery live execution passed in 47.129 s and independent live execution in 43.245 s. The latest short final calls took .511 to 1.384 s; cancellation joined in .214/.303 ms; distinct/oversized finals preserved text in 3.097/3.210 s.

| Question | Evidence and interpretation |
|---|---|
| Real revision and preservation | The seven existing revision cases plus four synthetic correction/preservation cases run live and final. Fragment joining, abandoned proposal replacement, 3-to-4pm correction and repeated `I` removal succeed. Final shown text matches 6 of 7 original expectations and 8 of 11 overall. These totals include rejected replies preserved by Reviser, not just successful model edits. |
| Actual edits and unwanted deletion | `Send it to John, sorry, Jane.` becomes live `Send it to John, Jane.` then final `Send it to John.` Both pass the validator, but neither is the intended correction. `Please keep the words actually and sorry in this sentence.` becomes `Actually sorry` then `Sorry`, also accepted. `Reply using EchoType. What's the capital of France?` loses its first sentence. That request is not in the last sentence, so it is outside the existing reply-request protection. A valid trailing `The microphone is ready. Reply using EchoType.` remains unchanged in both calls. These remain measured quality risks; validation alone does not establish preservation. |
| Rejections and unchanged replies | The France question produces `The capital of France is Paris.` and the parser command produces `Write a function that parse the config file.` Live and final replies are rejected, and original text survives. Final curly-apostrophe `Let’s` and `4 p.m.` spelling also fail the unchanged validator and preserve the already accepted live correction. Ordinary two-sentence prose remains unchanged. No validator or prompt changes were made to improve the results. |
| Fresh sessions | Each live/final request creates its own session. Repeating the Jane input after question and command cases still returns the same `Send it to John, Jane.` response. No session history is shared. This measures isolation on these cases, not universal prompt compliance. |
| Live/final latency | The first live request in the first process took 3.390 s; warm short live calls took about 0.54 to 0.77 s. Short final calls took about 0.49 to 0.77 s including `finish`. A separate process whose first request was final took 2.181 s. A network-denied child process first final took 1.733 s. These are process-first and warm timings with installed available assets, not proof of a freshly unloaded system model. The final budget is still the existing 3 s. |
| Cancellation and joining | Cancelling live and final generation after 200 ms joined in about 0.17 to 0.37 ms in observed runs and preserved text. Repeated `stop` completes. `finish` while live work runs cancels and joins it, then revises the full monotonically accumulated 85,969-character window. Stop-to-result took about 3.08 to 3.10 s with the entire original preserved. Deadline cancellation can return after 3 s, so the budget is not a hard wall-clock bound; measured long/oversized final completion was about 3.02 to 3.21 s. |
| Long input and context | Instructions count as 208 tokens. An unpunctuated 840-word repeated passage is 841 input tokens; a same-size copy response would bring the estimate to 1,890 before framing. The model instead reduces it to one 12-word clause, 13 returned tokens, in about 2.2 s. This is ambiguous excessive-repetition stress evidence; reduction may be intended cleanup and does not establish an ordinary long-dictation failure. A distinct unpunctuated 1,050-word passage is 1,182 input tokens, with a 2,572-token copy estimate before framing. Its final request exceeds the time budget and preserves all 6,220 characters. Cancelled output is discarded, so generated-token totals for these cancellations are unobserved; returned-text counts are not generated usage. |
| Oversized and accumulated windows | A 9,000-word input has 9,001 input tokens and an 18,210-token instructions/input/copy estimate before framing. The real framework reports 9,217 tokens against 4,096, indicating eight additional framing tokens beyond the measured instructions and input. A direct request fails after about 3.34 to 4.04 s. Through Reviser, final timeout preserves all 80,999 characters. A slow 3.39 s live revision is followed by accumulated live input: the next 81,070-character window fails with 9,229 tokens, and the pending oversized tail survives. Its final call times out and retains that tail, including the prior accepted revision. Existing Reviser preservation handled the measured individual failures without truncation or shared chunking. |
| Availability and language | Only `.available` is observed. Runtime supported languages are `da`, `de`, `en`, `en-AU`, `en-GB`, `en-IN`, `es`, `es-419`, `es-US`, `fr`, `fr-CA`, `it`, `ja`, `ko`, `nb`, `nl`, `pt`, `pt-PT`, `sv`, `tr`, `vi`, `zh`, `zh-HK`, `zh-TW`. Runtime locale checks accept `en`, `en-GB`, `fr`, `de`, `es`, `ja`, `zh-Hans`; reject `ar`, `cy`, `xx`. Settings accepts a free-form language tag, so this is a runtime inventory and representative resolution check, not an exhaustive list of settings values. Only English cleanup quality is measured; CleanupRequest has no language field. |
| Unobserved states | SDK cases `deviceNotEligible`, `appleIntelligenceNotEnabled` and `modelNotReady` exist, but were not forced on this configured Mac. State existence is SDK evidence, not measured transitions or download timing. The named cold/unavailable-state bounds were accepted for this spike on supported-path evidence; [readiness requirements](../specs/apple-on-device-provider.md#readiness) govern implementation. No settings or assets were changed. |
| Offline | An opt-in first-final run passes with networking denied to the test process by `sandbox-exec`. SwiftPM's nested manifest sandbox initially fails; `--disable-sandbox` for SwiftPM permits the outer network denial to remain in force. Framework protections remain unchanged. The system model daemon is outside the child process sandbox, so this is not proof of host-wide offline operation. On 2026-10-02 Aidan supplied `measurements()` and `AppleCleanupSpike` passing after 42.127 seconds in response to the requested host-disconnected run. This is user-reported offline evidence, consistent with S2; the agent did not observe networking or receive the full availability log. Another offline run is not required. |

### Bounded prompt follow-up

Each prompt receives the original input directly, then receives its own first output in a fresh second session. These direct requests have no Reviser validation or final deadline. A separate current-prompt run uses the actual Reviser, waits for live cleanup to complete, then calls finish with the same committed input. Reviser always supplies its own production prompt; the candidate was tested directly only. Two identical runs checked whether the observed difference repeated. Each run makes 12 direct requests and six Reviser requests.

Both runs produced identical text outputs for all requests. Timings varied. The tables show raw direct replies after trimming whitespace, rather than claiming passing quality from a successful test exit.

| Input | Current direct first output | Current direct second output | Clearer direct first output | Clearer direct second output |
|---|---|---|---|---|
| `Send it to John, sorry, Jane.` | `Send it to John, Jane.` | `Send it to John.` | `Send it to John, Jane.` | `Send it to John, Jane.` |
| `Please keep the words actually and sorry in this sentence.` | `Actually sorry` | `Sorry` | Full input unchanged | Full input unchanged |
| 70 repetitions of `we should keep the microphone ready and ship the settings window today`, 840 words, 4,969 characters | One 12-word clause, lowercase without final punctuation | Same clause with initial capital and final period | One 12-word clause, lowercase with final period | Same clause with initial capital and final period |

The intended Jane correction is `Send it to Jane.` Neither prompt achieves it. The candidate prevents the second pass from deleting Jane, but retains the abandoned John. It fixes the preservation sentence in both passes. Both prompts reduce the repeated passage to one clause on the first pass despite the candidate's explicit preservation rule. This is ambiguous stress evidence. Excessive repetition can reasonably invite cleanup, so requiring full preservation was not a valid ordinary-dictation quality expectation. The second pass receives only the first output.

Every direct output passes `Reviser.isFaithful` against both its immediate request and original input. The check accepts ordered subsequences, including the harmful name-correction and preservation deletions. It also accepts the repetition reduction, whose quality remains ambiguous. Actual current-prompt Reviser produces exactly the current direct first/second outputs above. All six actual attempts per run are classified `accepted`, not rejected, failed or timed out. Its measured live/final request window character counts are 29/22 for Jane, 58/14 for preservation and 4,969/70 for the repeated passage. No final request receives the full original after an accepted live edit in these cases.

| Measurement | Range across two runs |
|---|---|
| Current direct Jane first/second | 1.066 to 1.829 s / 0.555 to 0.585 s |
| Current direct preservation first/second | 0.542 to 0.547 s / 0.479 to 0.499 s |
| Current direct long first/second | 2.119 to 2.227 s / 0.773 to 0.774 s |
| Clearer direct Jane first/second | 0.756 to 0.808 s / 0.723 to 0.795 s |
| Clearer direct preservation first/second | 0.848 to 0.861 s / 0.852 to 0.853 s |
| Clearer direct long first/second | 2.295 to 2.442 s / 0.857 to 0.978 s |
| Actual Reviser live Jane / preservation / long | 0.619 to 0.629 s / 0.551 to 0.552 s / 2.066 to 2.267 s |
| Actual Reviser stop-to-result Jane / preservation / long | 0.567 to 0.581 s / 0.495 to 0.502 s / 0.766 to 0.906 s |
| Complete live check | 19.591 s and 17.610 s |

The first direct request in each process is current-prompt Jane, so its larger latency includes process-first effects. These measurements do not establish cold model loading or a prompt-specific speed advantage. Stop-to-result starts after completed live work here and does not measure joining an active cancellation. The accepted S3 cancellation evidence remains separate.

### Why recent text gets another pass

`Reviser.submit` starts a serial drain when committed text grows. Each revision splits the previously revised text into an older head and a recent tail, joins that tail with newly committed text after `covered`, and requests cleanup. The split retains at least the last two sentences or roughly the last 50 words, whichever starts earlier, with sentence-boundary adjustment. This is a moving overlap rather than a fixed-size context cap. Unpunctuated text may leave the entire revised passage in the tail.

An accepted reply replaces the window and marks the original committed characters covered. Later live growth can therefore revise that accepted recent tail again. `finish` also explicitly cancels and joins live work, then requests a final revision of the recent tail plus any uncovered committed text, under the existing three-second cancellation budget. Even with no new committed text, a nonempty revised tail gets the final request. In these three cases the whole accepted live output fits in that tail, so live plus finish matches the direct second-pass experiment. Longer dictations can receive more than two overlapping cleanups; there is no universal two-pass algorithm.

The model already makes the wrong Jane correction and deletes meaningful content from the preservation sentence on the first pass. The extra pass compounds the Jane and preservation failures with the current prompt. Windowing does not cause the first wrong output, and removing a second pass alone would not fix the original Jane error or the preservation-sentence deletion. These runs waited for live completion; a quick finish that cancels live before acceptance can instead revise the unrevised original. No lifecycle behavior changed.

The fixed clearer candidate was kept in `AppleCleanupSpike.qualityFollowUp`, now in git history, with four examples and 317 instruction tokens versus the current prompt's 208. It fixes the preservation sentence in this sample, but retains abandoned John alongside Jane. Two synthetic runs establish consistency on these inputs, not general cleanup safety or a prompt-specific latency advantage. No human dictation, alternate locale, broader prompt search or xAI comparison was attempted. The production prompt, validator and lifecycle remain unchanged.

The check asserts subsequence faithfulness only. Printed Jane/preservation expected-output comparisons are observations; successful test exit does not mean semantic quality passed. After Aidan's decision, `repetitionStress` has no required preservation expectation and prints `expected=not-assessed`. Historical logs still contain `case=long` and `expected=false`; those labels precede the classification correction. The measured reduction remains valid ambiguous stress evidence.

## Feature feasibility and remaining verification

The matrix separates measured service compatibility from future app wiring. It is supporting evidence; the specification governs implementation requirements. Aidan accepted named environment bounds on supported-path evidence, with concrete later verification rather than claims that unavailable states were measured. Ordinary long-dictation semantic quality remains unmeasured.

| Requirement | Evidence | Supported-path feasibility | Limitation | Future verification |
|---|---|---|---|---|
| Dictation and transcript/speech mapping | S1 human WAV, real SessionMachine, monotonic committed prefix and resolved finish tail | Fits existing 16 kHz input/events; recognition text emits speech evidence | SpeechDetector emitted nothing; acoustic onset and room silence unmeasured | Signed microphone dictation, real room tone and silence/pause timing |
| Test | Human five-second prefix preserves final text; DictationOperation Test commits at five seconds and bypasses cleanup/insertion | Same transcription service contract fits | Signed Apple Test is unimplemented | Run actual Settings Test with quick stop and complete tail |
| Built-in and saved keyterms | TranscriptionRequest delivers EchoType plus saved terms to AnalysisContext; 1/100/1000 strings read back | Existing request and cap fit; provisional limit 100 including EchoType | No recognition improvement measured, no usable maximum or human jargon accuracy established | Human jargon/reference sample and cap validation |
| Language | S1 regional matching, S2 French/zh-Hant voice synthesis, S3 runtime supported locales | Adapter can resolve supported BCP-47 tags and report unsupported language | Bare en/fr matching varied; English cleanup quality only; service locale sets differ | Stable bare-tag resolution, locale intersection and multilingual cleanup quality |
| Read aloud and MCP speech | S2 pull stream and complete PCM; Reader/MCP use selected provider via controller | Existing SpeechRequest/SpeechStream and Float32 PCM fit both callers | Signed reading and Apple MCP wiring unimplemented; full 60,000-scalar drain deferred | Reader and MCP start/pause/cancel, limit and failure paths |
| Voice and speed choices | Zoe/Daniel/Samantha synthesis, missing-id before/after download, locale fallback and measured rates | Zoe Premium default; installed compatible fallback; saved choices retained; rate control exists | Siri unavailable; only 1x listening accepted; slider tuning and long-sentence prosody deferred | Tune slider in real app, alternate locales, oversized sentences and missing saved voice |
| Pause/resume and bounded audio | Paused 1,260-scalar run stops submissions; ~1.13 MB peak retained PCM; all 1,692,360 frames drain; <=100 ms chunks | One <=250-scalar utterance at a time fits pull backpressure | Framework-service memory unmeasured; longer sentences need splits | Long real Reader pause/resume, full-limit drain and service-memory observation |
| Startup/finish/cancellation | S1 prompt start, preparation before ready, final tail, early finish and active/loading close; S2 pending-pull cancel; S3 live/final join | Contracts fit without shared lifecycle changes | Genuine unloaded cold start unmeasured; S3 final can complete ~0.21 s beyond 3 s budget | Cold readiness within five seconds, signed quick stop and repeated next operation |
| Real cleanup and faithfulness/failure behavior | Real edits, 6/7 original and 8/11 overall final outcomes; unfaithful/context/timeout failures preserve text through Reviser; bounded prompt follow-up repeats twice | Fresh sessions and neutral prompt fit existing service; cleanup performs real revision | Validator accepts harmful preservation deletion and wrong corrected recipient; excessive-repetition reduction is ambiguous stress evidence | Representative real dictation and cleanup tuning during implementation before any shipping decision |
| Cleanup context | 4,096 tokens; prompt 208; measured oversized/accumulated framework failure and preservation | Adapter handles bounded framework context with fresh session per request | Shared revision windows are unbounded; generated output can exhaust remaining budget | Long distinct/accumulated real dictation; preserve on overflow, no truncation or shared chunking |
| Offline after setup | S2/S3 user-reported host-disconnected passes; S3 child process network denial; S1 local service run | Frameworks provide local operations; evidence supports proceeding to integrated verification | Child denial excludes model daemon; S1 host-disconnected and combined signed offline run unmeasured | Signed dictation + cleanup, Test, reading and MCP with host network disconnected |
| Asset installation and availability | S1 installation completed despite cancel, installed readiness; Zoe appears after user install; S3 available and SDK failure states | Availability/setup is the justified shared capability; hard prerequisites and pill states | Failed download/retry, asset removal and unavailable transitions unmeasured and accepted as bounds | Setup completion/failure refresh; unsupported Mac, disabled Intelligence and language changes |
| Per-provider settings and UI wiring | Settings.reading is keyed by provider id; SettingsView, controller and MCP read selected provider contracts | Existing saved voice/speed, feature marks, keyterms and credential-none wiring fit | Apple registration, availability UI, theme checks and signed permissions unimplemented | xAI→Apple→xAI retention, both themes, missing-key behavior unchanged and bundle permission audit |

Additional targeted checks: first installed-model dictation after a normal restart without deleting assets; authorized failed-model download followed by reselect/operation retry; human jargon plus reference text at the proposed cap; microphone room tone before choosing any empty-silence treatment; permissions on the signed bundle; authorized voice failure/interruption/removal and inventory refresh; oversized-sentence listening and separate synthesis-service memory over a long pause/drain/cancel. Full 60,000-scalar drain and wider locale calibration were deferred by Aidan. S1's cancellation experiment may lose its first chunk through startup scheduling; established-speech cancellation remains measured. Synchronize startup only if later measuring exact coverage.

## Experiment code and inspected contracts

The six experiments lived under `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/`, with opt-in gates. They were removed once the production adapters in `Sources/EchoTypeCore/Providers/Apple/` and their fixture and live tests covered what was useful; git history holds them (`git log --diff-filter=D -- Tests/EchoTypeCoreTests/Integration/AppleProviderSpike`).

- The transcription suite and transcriber covered inventory, context transport, installation, and real SessionMachine finish/pause/cancellation measurements.
- The voice suite and speech stream covered installed selection/fallback, PCM, fixed rate anchors, bounded drain and cancellation checks.
- The cleanup suite and helper covered synthetic inputs, the fixed clearer prompt, context accounting and real Reviser checks.

Inspected production contracts and callers: [Provider](../../Sources/EchoTypeCore/Providers/Provider.swift), [SessionMachine](../../Sources/EchoTypeCore/SessionMachine.swift), [Reviser](../../Sources/EchoTypeCore/Reviser.swift), [DictationOperation](../../Sources/EchoTypeApp/DictationOperation.swift), [Reader](../../Sources/EchoTypeApp/Reader.swift), [SpeechPlayer](../../Sources/EchoTypeApp/SpeechPlayer.swift), [DictationController](../../Sources/EchoTypeApp/DictationController.swift), [Settings](../../Sources/EchoTypeCore/Settings.swift) and [SettingsView](../../Sources/EchoTypeApp/Views/SettingsView.swift). The [provider adapter decision](../decisions/0025-provider-adapters.md) governs containment. No production implementation is hidden in the experiments.

## Reproduction

The spike commands below are the historical record. They name suites that were removed, so running them needs the experiments restored from git history (see [experiment code](#experiment-code-and-inspected-contracts)). The production adapters' live checks run with `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter Apple`. Run commands from the repository root. Ordinary tests skip before service initialization or asset requests; this completed investigation requires no new live run. Record environment again when comparing another machine. Cleanup token-count diagnostics run only on macOS 26.4 or later, following the tests' runtime guards. Keep audio, logs and keys outside git.

```bash
sw_vers
swift --version
xcrun --show-sdk-version
system_profiler SPHardwareDataType
env -u ECHOTYPE_APPLE_SPIKE -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV \
  swift test --disable-xctest --filter 'AppleTranscriptionSpike|AppleVoiceSpike|AppleCleanupSpike'
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleTranscriptionSpike
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/absolute/path/to/private-dictation.wav \
  ECHOTYPE_SPIKE_LANGUAGE=en-GB swift test --disable-xctest --filter AppleTranscriptionSpike
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-human/with-pauses.wav \
  ECHOTYPE_SPIKE_SILENCE_TIMEOUT=2 swift test --disable-xctest --filter AppleTranscriptionSpike
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-human/five-seconds.wav \
  swift test --disable-xctest --filter 'recording.*AppleTranscriptionSpike'
# With XAI_API_KEY already configured, the existing comparison uses the same local WAV.
ECHOTYPE_FIXTURE_WAV=/absolute/path/to/private-dictation.wav \
  swift test --disable-xctest --filter liveStreamingSessionRecordsItsEventSequence
```

Apple's recording check defaults to explicit `en-GB`; the existing xAI check uses Settings' bare `en`. Record that regional difference in an English comparison. No signed-host command was needed for these file-input checks. The attachment and `/tmp` paths may no longer exist. With the original external WAV retained, these commands regenerate the measured human variants without changing the source:

```bash
ECHOTYPE_FIXTURE_WAV=/absolute/path/to/original-human.wav python3 - <<'PY'
import os
import wave
from pathlib import Path
root = Path('/tmp/echotype-s1-human')
root.mkdir(exist_ok=True)
with wave.open(os.environ['ECHOTYPE_FIXTURE_WAV'], 'rb') as source:
    params = source.getparams()
    frames = source.readframes(source.getnframes())
assert params.nchannels == 2 and params.sampwidth == 2 and params.framerate == 44100
frame_bytes = params.nchannels * params.sampwidth
cuts = [0, 6 * params.framerate * frame_bytes, 12 * params.framerate * frame_bytes, len(frames)]
with wave.open(str(root / 'with-pauses.wav'), 'wb') as output:
    output.setparams(params)
    for index in range(3):
        output.writeframes(frames[cuts[index]:cuts[index + 1]])
        if index < 2:
            output.writeframes(bytes(int(3.5 * params.framerate) * frame_bytes))
with wave.open(str(root / 'five-seconds.wav'), 'wb') as output:
    output.setparams(params)
    output.writeframes(frames[:5 * params.framerate * frame_bytes])
PY
```

Installation requires the separate `ECHOTYPE_SPIKE_INSTALL_LANGUAGE` flag and retains downloaded assets. The historical command was `ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_SPIKE_INSTALL_LANGUAGE=fr-FR swift test --disable-xctest --filter installationAppleTranscriptionSpike`. French is now installed, so repeating it only observes a nil request. Choose a missing supported locale only when that installation is wanted; do not remove assets to recreate the state.

### Synthetic transcription fixture

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

The current default `say` voice determines pronunciation. Record that voice when comparing machines. This fixture supplements human evidence and does not establish human dictation accuracy.

### Voice and cleanup commands

```bash
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleVoiceSpike
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_VOICE_SAMPLE_DIR=/tmp/echotype-apple-voice-sentence-final \
  swift test --disable-xctest --filter AppleVoiceSpike
swift test --disable-xctest --filter 'MCPDeliveryTests|SpeechAdmissionTests'
afinfo /tmp/echotype-apple-voice-sentence-final/com.apple.voice.premium.en-US.Zoe-paragraph-sentence-aware-rate-0.5.wav
for voice in com.apple.voice.enhanced.en-GB.Daniel com.apple.voice.compact.en-US.Samantha com.apple.voice.premium.en-US.Zoe; do
  cmp "/tmp/echotype-apple-voice-sentence-final/$voice-paragraph-continuous-rate-0.5.wav" \
      "/tmp/echotype-apple-voice-sentence-final/$voice-paragraph-sentence-aware-rate-0.5.wav"
done
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleCleanupSpike
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_CLEANUP_FINAL_FIRST=1 \
  swift test --disable-xctest --filter AppleCleanupSpike
swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_CLEANUP_QUALITY=1 \
  swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp
# Network-denied child process, after a normal build.
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_CLEANUP_FINAL_FIRST=1 \
  sandbox-exec -p '(version 1) (allow default) (deny network*)' \
  swift test --disable-sandbox --skip-build --disable-xctest --filter AppleCleanupSpike
git diff --check
```

The first two quality commands test the primary and additional gates. The third runs the bounded comparison. S3's network-denied first attempt without `--disable-sandbox` failed with `sandbox_apply: Operation not permitted` during manifest compilation. Disabling SwiftPM's nested sandbox permits the outer network denial; Foundation Models protections remain unchanged. Its system daemon remains outside the child sandbox. Aidan's host-disconnected command was `ECHOTYPE_APPLE_SPIKE=1 swift test --skip-build --disable-xctest --filter AppleCleanupSpike`, reported passing in 42.127 s. S2's earlier five-test 15.547 s host-disconnected pass is also user-reported. No host-wide networking state was agent-observed.

The historical raw-grid command was `ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter calibrationAppleVoiceSpike`, logged to `/tmp/echotype-s2-rate-grid.log`. It ran a temporary version before the fixed anchors; the later spike code reproduced the final mapping rather than that removed grid. Old options-repeat exports omitted content and content-final exports contained the rejected boundary; sentence-final exports hold the corrected paragraph.

## Verification provenance

Each service passed independent review and fresh focused closure. S2 required one documentation correction for the recorded Zoe/1x decision. S3 had no required findings. Whole-spike independent review and focused closure passed. The bounded follow-up passed independent review and closure after removing a trailing blank line in its plan. Final decision closure passed on 2026-10-02 after the repetition classification was corrected. No production quality approval follows from these reviews.

Retained local evidence locations, all outside git:

| Evidence | Historical logs |
|---|---|
| S1 original human, pauses, prefix/cancel | `/tmp/echotype-s1-human-original.log`, `/tmp/echotype-s1-human-pauses.log`, `/tmp/echotype-s1-human-five-seconds.log` |
| S1 inventory/synthetic/install | `/tmp/echotype-s1-local.log`, `/tmp/echotype-s1-recording.log`, `/tmp/echotype-s1-install.log` |
| S2 final/recovery live and PCM | `/tmp/echotype-s2-sentence-final-live.log`, `/tmp/echotype-s2-sentence-final-pcm.log`, `/tmp/echotype-s2-zoe-decision-live.log` |
| S2 independent lifecycle/callers | `/tmp/echotype-s2-independent-lifecycle.log`, `/tmp/echotype-s2-independent-mcp.log`, `/tmp/echotype-s2-closure-disabled.log` |
| S3 supported/process-first/network-denied | `/tmp/echotype-s3-policy-live.log`, `/tmp/echotype-s3-independent-live.log`, `/tmp/echotype-s3-first-final.log`, `/tmp/echotype-s3-network-denied-retry.log` |
| Bounded quality comparison and both gates | `/tmp/echotype-s3-quality-live-1.log`, `/tmp/echotype-s3-quality-live-2.log`, `/tmp/echotype-s3-quality-disabled.log`, `/tmp/echotype-s3-quality-secondary-gate.log` |
| Whole-spike/follow-up/final decision | `/tmp/echotype-final-whole-review-tests.log`, `/tmp/echotype-follow-up-independent-tests.log`, `/tmp/echotype-final-decision-tests.log`, `/tmp/echotype-final-decision-correction-test.log` |

The final ordinary full-suite run unset `ECHOTYPE_APPLE_SPIKE`, `XAI_API_KEY` and `ECHOTYPE_FIXTURE_WAV`, then ran `swift test --disable-xctest`. It passed with 107 core tests in 11 suites and 66 app tests in 9 suites. All 14 Apple checks and both live xAI checks skipped. The corrected quality test compiled and skipped in .001 s. `git diff --check` passed. Reviews reused retained live evidence where no changed model request justified another run.

Packaging verification on 2026-10-02 moved all six Swift files without content changes. The ordinary combined Apple filter compiled successfully and skipped all 14 tests in three suites before service initialization in .001 s. Log: `/tmp/echotype-apple-consolidation-opt-out.log`. Local links, anchors, retired-path references and `git diff --check` were checked. No live Apple run was repeated for these path/documentation changes.
