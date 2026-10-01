# 0021 Revise committed dictation during the session

Status: accepted, 2026-09-27. Live timing and window updated 2026-09-28. Rejected
revisions advance and the window shrinks to 50 words from 2026-09-29. Cleanup always on,
through a provider's cleanup service, from 2026-10-01. Supersedes the batch pass in
[0017](0017-batch-pass-on-commit.md).

Lifetime and related timing/presentation rules are superseded by
[0024](0024-dictation-operation-lifetime.md). The original record is retained below.

## Context

The streaming transcript can put a full stop at a thinking pause and preserve words the
speaker later takes back. The former batch pass could join sentences after stop, but the
pill showed different text from what it inserted and the pass did not reliably remove
self-corrections. It also kept the whole recording in memory and delayed every insertion.

## Decision

- Cleanup is always on. After each `speech_final`, revise committed text
  while the current utterance's settled and provisional runs continue to appear as
  streamed. The pill shows accepted revisions, and its final text is what gets inserted.
  When the provider has no cleanup service, insert the streamed transcript. The Test
  button never revises. (Until 2026-10-01 a **Clean up text** setting, on by default,
  could turn cleanup off. The [provider adapters specification](../specs/provider-adapters.md)
  removed it, and its stored `cleanUp` key is now ignored.)
- `Reviser` owns the prompt, the windows and the faithfulness check, which are product
  behaviour. Each request goes through the provider's `CleanupService` with the prompt,
  the window, whether it is final and the credential. The model, temperature, reasoning
  effort and timeouts are adapter details; for xAI they live in `Providers/XAI/`.
- Send a recent window: the revised text from whichever starts earlier, its second-to-last
  sentence or the sentence containing its 50th word from the end, plus committed text
  not yet revised. Keep one request in flight and combine commits that arrive while it
  runs. At stop, cancel the live request and make one final revision of the remaining
  window. A failed session keeps accepted revisions and the unrevised committed tail
  without a final call.
  Fifty words is two or three spoken sentences. The word minimum stops short phrases
  split at pauses from shrinking the window to a few words. It was 100 until 2026-09-29,
  which re-revised each sentence five or more times as it moved back through the window.
- Accept a revision only when its words appear in the input in the same order after
  lowercasing, splitting at hyphens and dashes, and stripping punctuation at word edges.
  This permits deletions, including a stutter such as `I-I'm` to `I'm`, and punctuation
  changes, but rejects added, substituted, or reordered words. If the call fails, times
  out, returns empty text, or fails this check, keep the streamed input for that stretch
  without showing an error, and count it as revised. It still returns in later windows
  while it is part of the recent tail. (Before 2026-09-29 a rejected stretch stayed
  unrevised, so an edit the model kept making was rejected in every later window and
  the final call received the whole dictation.)
- Replace **Re-transcribe on stop** and its `batchOnCommit` setting with cleanup.
  Ignore the old stored key. Remove the batch request and
  in-memory recording buffer.
- Use `endpointing=1200` so a pause can commit an utterance and start live cleanup sooner.

## Consequences

- Requests normally cover whole recent sentences and at least 50 revised words when available,
  rather than the whole dictation. The user can see corrections before stopping. A long
  unpunctuated tail can still make a large window. The final request can
  delay insertion; live and final requests have separate resource timeouts. Aidan reported
  insertion under one second after stop in the final Mac check.
- The word check deliberately rejects some useful rewrites, such as `four pm` to `4pm`,
  and can permit excessive deletion. Scripted tests and real prompt cases cover the
  expected corrections and unchanged inputs; an uncertain or rejected result leaves the
  spoken words in place.
- [0003](0003-transcript-assembly.md) separates append-only committed text from the
  current utterance so revision cannot mistake a replaced partial run for a new commit.
