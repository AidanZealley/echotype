# 0023 A Last Dictation window shows the last dictation's trace

Status: accepted, 2026-09-29.

## Context

Cleanup is inconsistent and nothing showed why. `Reviser` drops failed, timed-out and
rejected requests silently ([0021](0021-revise-committed-dictation.md)), so a fragmented
dictation looked the same whether no revision ran, every revision was rejected, or the
model returned the text unchanged. Finding out meant reproducing the requests by hand.

## Decision

- **Every launch records the last dictation.** There is no setting and no launch flag.
  **Last Dictation…** sits below **Settings…** in the menu and is the only way to open
  the window. `--hud-demo` records no dictation, so it has no item. The trace stays in
  memory: it is not written to disk, logged or sent anywhere.
- **One value, `DictationTrace`, is both what the window renders and what Copy as JSON
  encodes.** It holds each growth of committed text with its time, every revision request
  with its window, raw reply, latency and result, the streamed and inserted text, and the
  session outcome. `inserted` is exactly the text passed to the inserter, so a failed
  session that inserted its surviving text shows it.
- **Only the last dictation that reached `running` is kept.** Inserted, failed, cancelled
  and empty dictations all replace it; the Test button and read-aloud never do. A
  cancelled session is told apart from an empty one by the last snapshot's state.
  Cancellation doesn't wait for an in-flight revision just to complete the trace.
  `Reviser` records every request it makes.
- **Words are marked with the faithfulness rule.** Streamed and inserted text split into
  words and normalise as `Reviser.isFaithful` does, sharing one tokenizer. Each inserted
  word matches the next equal streamed word. Unmatched streamed words are deleted
  (struck through, red); a matched word whose raw form differs is changed (inserted form
  in amber, streamed form on hover). A thin mark before the word where a commit starts
  shows the time since the previous commit on hover. When a word repeats, the walk may
  strike a different copy than the model removed; the text reads the same.
- **The paragraph is a non-editable `NSTextView`.** SwiftUI's `Text` wraps and selects an
  `AttributedString` paragraph, but has no hover for part of it. The text view gives the
  same wrapping and selection and shows each run's tooltip.
- **The window activates like Settings ([0011](0011-settings-window-activation.md)).**
  Both menu items share one helper, which replaces 0011's `SettingsButton`. It makes the
  app regular, opens the window, activates on the next turn and raises the app's
  frontmost main-capable window. Either window's close returns the app to an accessory
  app only when no other main-capable window is still visible or minimised. The window
  never opens at launch, so the app always starts as an accessory app. A dictation ending
  only changes `lastTrace`, so the open window updates without moving in front or taking
  focus.

## Change of decision

The window first shipped behind a development-only `--debug` launch flag, with no
recording and no menu item without it. After checking it on the Mac, Aidan decided on
2026-09-29 that it is useful to everyone and removed the gate from the whole window,
diagnostic detail included. The flag no longer exists.

## Consequences

- One dictation is kept. Dictating again before looking loses the previous trace. If
  that happens regularly, keep the last three and add a picker.
- Time between commits includes speaking time, so it only roughly stands in for pause
  length. If endpointing is the suspect, record the gap between the last partial of one
  utterance and its `speech_final` instead.
- Hyphens and dashes separate words and appear in no mark, so the stutter `I-I'm` shows
  as `I` struck through and `I'm`, and `well known` revised to `well-known` shows as kept.
- A session where nothing is said ends when the silence timeout calls `cancel()`, so it
  records as cancelled, like Escape, not as empty.
- A cancelled request may be missing from the list when its call hadn't returned by the
  time the trace was published.
- Selecting and copying the marked text includes the commit marks.
- Every dictation keeps its revision windows and replies in memory until the next
  dictation that reaches `running` replaces them.
