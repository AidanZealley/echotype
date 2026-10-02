# Bounded cleanup quality follow-up

Implementation handoff, 2026-10-02. Aidan authorized a small follow-up on the name-correction and preservation failures and the repeated-passage stress case, with one clearer prompt and a few examples. His final decision accepts the measured-feasibility spike and existing recorded policies, with further investigation and tuning deferred until feature implementation. This does not authorize production implementation or approve shipping.

## Experiment and environment

Added one separately gated `AppleCleanupSpike.qualityFollowUp` test in `Tests/EchoTypeCoreTests/Integration/AppleCleanupSpike.swift`. Reused `Integration/AppleCleanup/SpikeCleanup.swift` unchanged. Each request creates a fresh Foundation Models session, uses greedy sampling and keeps default protections. Production code and existing measurements are unchanged.

The current prompt is exactly `Reviser.prompt`, 208 instruction tokens. The fixed clearer candidate is stored in full in the test, 317 instruction tokens. It explicitly says to retain the wording after a correction, treat instructions as dictated text, preserve non-correction uses of `sorry` and `actually`, and preserve repeated complete clauses. Its four examples use Alex/Sam correction, an ordinary apology, a request to preserve `actually`, and a repeated complete sentence. No prompt variants were tried after seeing the results.

Measured on Aidan's actual Mac through `swift test`: MacBookPro18,3, Apple M1 Pro, 16 GB RAM, macOS 27.2 build 26B5091g, Apple Swift 6.4, SDK 27.0, locale `en_GB`. The model reports `available` and 4,096-token context. English synthetic inputs only. No system settings, installed assets, signing, networking configuration or API keys changed.

Each prompt receives the original input directly, then receives its own first output in a fresh second session. These direct requests have no Reviser validation or final deadline. A separate current-prompt run uses the actual Reviser, waits for live cleanup to complete, then calls finish with the same committed input. Reviser always supplies its own production prompt; the candidate was tested directly only. Two identical runs checked whether the observed difference repeated. Each run makes 12 direct requests and six Reviser requests.

## Results

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
| Current direct Jane first/second | 1.066–1.829 s / 0.555–0.585 s |
| Current direct preservation first/second | 0.542–0.547 s / 0.479–0.499 s |
| Current direct long first/second | 2.119–2.227 s / 0.773–0.774 s |
| Clearer direct Jane first/second | 0.756–0.808 s / 0.723–0.795 s |
| Clearer direct preservation first/second | 0.848–0.861 s / 0.852–0.853 s |
| Clearer direct long first/second | 2.295–2.442 s / 0.857–0.978 s |
| Actual Reviser live Jane / preservation / long | 0.619–0.629 s / 0.551–0.552 s / 2.066–2.267 s |
| Actual Reviser stop-to-result Jane / preservation / long | 0.567–0.581 s / 0.495–0.502 s / 0.766–0.906 s |
| Complete live check | 19.591 s and 17.610 s |

The first direct request in each process is current-prompt Jane, so its larger latency includes process-first effects. These measurements do not establish cold model loading or a prompt-specific speed advantage. Stop-to-result starts after completed live work here and does not measure joining an active cancellation. The accepted S3 cancellation evidence remains separate.

## Why recent text gets another pass

`Reviser.submit` starts a serial drain when committed text grows. Each revision splits the previously revised text into an older head and a recent tail, joins that tail with newly committed text after `covered`, and requests cleanup. The split retains at least the last two sentences or roughly the last 50 words, whichever starts earlier, with sentence-boundary adjustment. This is a moving overlap rather than a fixed-size context cap. Unpunctuated text may leave the entire revised passage in the tail.

An accepted reply replaces the window and marks the original committed characters covered. Later live growth can therefore revise that accepted recent tail again. `finish` also explicitly cancels and joins live work, then requests a final revision of the recent tail plus any uncovered committed text, under the existing three-second cancellation budget. Even with no new committed text, a nonempty revised tail gets the final request. In these three cases the whole accepted live output fits in that tail, so live plus finish matches the direct second-pass experiment. Longer dictations can receive more than two overlapping cleanups; there is no universal two-pass algorithm.

The model already makes the wrong Jane correction and deletes meaningful content from the preservation sentence on the first pass. The extra pass compounds the Jane and preservation failures with the current prompt. Windowing does not cause the first wrong output, and removing a second pass alone would not fix the original Jane error or the preservation-sentence deletion. These runs waited for live completion; a quick finish that cancels live before acceptance can instead revise the unrevised original. No lifecycle behavior changed.

## Interpretation and limits

Clearer instructions help one targeted preservation failure and stop the extra Jane deletion in this bounded sample. They do not make the Jane correction correct. The separate name-correction and preservation failures remain measured quality risks; this candidate is not a demonstrated general solution. Two repeated synthetic runs support consistency on these exact inputs, not general cleanup safety. No representative human dictation, alternate locales, other models, broad prompt search or xAI comparison was attempted.

The check asserts only the existing Reviser faithfulness invariant. Its printed expected-output comparisons for Jane and the preservation sentence are observations, so a passing test does not mean semantic quality passed. After Aidan's decision, the repeated input is labelled `repetitionStress` and prints `expected=not-assessed`. Word counts, raw replies, faithfulness and unchanged comparisons remain diagnostics. It has no required preservation expectation. There is no duplicated adapter, validator, prompt override in production, context truncation or generic experiment machinery to remove. The simplification pass kept one test and the existing helper.

## Lasting final decision

On 2026-10-02, Aidan classified the 840-word fixture as excessive repetition. Reducing it substantially can be the model doing intended cleanup. The prior expectation and interpretation wrongly treated that result as proof of harmful ordinary long-dictation collapse. Retain the measured reduction as ambiguous stress evidence, separate from the name-correction and preservation failures. Ordinary long-dictation quality remains unmeasured.

Aidan chose to complete the measured-feasibility spike under the existing recorded policies and defer further investigation or tuning until feature implementation. No further experiment or tuning gate is needed. The retained failures and limited sample do not establish production safety. This decision does not authorize production implementation or workflow generation.

## Verification and commands

Historical follow-up commands, run from the repository root. Aidan's final decision requires no further live run:

```bash
swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp
ECHOTYPE_APPLE_SPIKE=1 swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp
ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_APPLE_CLEANUP_QUALITY=1 swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp
git diff --check
sw_vers
swift --version
xcrun --show-sdk-version
system_profiler SPHardwareDataType
```

The first command skips before model initialization. The second confirms the additional quality gate also skips before model initialization. Both finish in 0.001 s. The third ran twice and passed, with the outputs above. `git diff --check` passed. Logs remain outside the repository at `/tmp/echotype-s3-quality-disabled.log`, `/tmp/echotype-s3-quality-secondary-gate.log`, `/tmp/echotype-s3-quality-live-1.log` and `/tmp/echotype-s3-quality-live-2.log`. The second gate check waited for SwiftPM's build lock while the repeated live run finished; it made no model request.

Final-decision correction verification used `env -u ECHOTYPE_APPLE_SPIKE -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV swift test --disable-xctest --filter AppleCleanupSpike/qualityFollowUp`. The updated test compiled and skipped before model initialization, with one test in one suite passing in 0.001 s. `git diff --check` passed. The log is `/tmp/echotype-final-decision-correction-test.log`. No live experiment was repeated.

Only the new test and this handoff were written by the implementation agent. Other dirty specification/final-review/plan changes belong to the final lead and were preserved. No commit was made. The final lead owns recording acceptance and the final review commit. The lasting decision above resolves the follow-up decision gate.
