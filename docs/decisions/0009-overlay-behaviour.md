# 0009 How the overlay behaves during a session

Status: accepted, 2026-09-24 (overlay gate G2). Supersedes the error surface in
[0006](0006-api-key-and-error-surface.md). The meter's input is superseded by
[0012](0012-capture-with-avcapturesession.md). Live revision superseded click-to-stop
on 2026-09-26 during the preview redesign.

Lifetime and related timing/presentation rules are superseded by
[0024](0024-dictation-operation-lifetime.md). The original record is retained below.

Aidan's 2026-09-30 addition shows "Select an input" while recording without a
conservative focused destination text field. "Starting" remains until microphone audio
flows. Focus readiness is advisory and updates during silence; recording and finishing-time
destination capture keep their existing behavior. Dictation error text uses the transcript's
1.5 line-height multiple. Select an input and dictation's final minute show a fixed orange dot beside plain text, with the level glow turned orange; coloured text alone was illegible on light glass over dark windows (G7, 2026-10-01). Implementation is recorded in 0024. G4 passed under Aidan's approved reduced-core scope; alternate-theme and changed error/amber layout checks remain unverified.

Reading's accepted lifecycle rewrite derives Starting, Reading and Paused from the
operation, including remembered pause before audio arrives. Stop hides the reading pill
while Copy cleanup finishes. Old callbacks cannot update a replacement's pill or levels.
The implementation and bounded playback policy are recorded in [0018](0018-read-aloud-audio-fetch.md).
G5 passes with signed startup pause/held repeats, playing pause/resume, paused Escape/pill removal and newest-only audible startup supersession. Replacement isolation is deterministically reviewed; signed pending-Copy and paused-reading dictation takeover remain unverified under Aidan's explicit deferral.

## Context

The overlay must never take focus, since a lost focus sends the insertion nowhere. It also
became the place for errors, a click target and something Escape can dismiss while the
microphone opens. Several of these needed decisions the specification leaves open, and
two differ from it.

## Decision

- `OverlayPanel` owns a private `NSPanel` subclass rather than being one, so nothing
  can call `makeKey` or `makeMain` on it. The subclass refuses key and main status. The
  panel is borderless and non-activating from init, floats at `.screenSaver` level and
  is shown only with `orderFrontRegardless()`. `hidesOnDeactivate` is false, because
  this app is never active and the panel would otherwise never appear. It adds
  `.ignoresCycle` to the specification's collection behaviour.
- Originally, the panel took clicks in `sendEvent` and committed a running session or
  stopped a reading. Live revision removed that interception. The later approved
  preview follows the newest text without user scrolling. Its transcript area grows to a
  184pt cap, then fades and clips older text at the top while the panel's lower edge stays
  anchored, with no height animation. Opt+D still commits, and the read-aloud hotkey or
  Escape still stops reading.
- The event tap callback only changes the controller's phase, which the consume decision
  reads, and starts tasks for everything else. The next key event is still judged against
  the right phase. (Read aloud: a reading press also finds the pill's screen in the
  callback, so the pill is ready before the reader reports.)
- Escape during the starting state is consumed and abandons the start: the pill fades at
  once, the microphone is released and no socket opens. Opt+D is ignored until the
  abandoned start unwinds.
- The pill switches from starting to listening on the first audio buffer from the
  microphone, not the first 100ms chunk the specification names. The pump does not read
  the chunk stream until the session is listening, so the first chunk cannot be observed
  without a relay. The buffer comes at most about 85ms earlier.
- Failures and a missing API key show in the pill in red for three seconds, then it
  fades. A new Opt+D cancels that fade. Any settled text is still inserted. The menu bar's
  state line shows only the session state.
- The meter reads the loudest channel's RMS before conversion, mapped linearly from
  -50 dBFS (empty) to -20 dBFS (full), so ordinary speech sits around two thirds. (Superseded: the meter
  now reads the converted mono audio, with the same mapping. While reading, it reads the
  player's output as it plays, with the same mapping.)
- The pill goes on the screen containing the centre of the frontmost app's focused
  window, read through Accessibility. It falls back to the screen under the mouse, then
  the main screen. Each Accessibility read has a 0.25s timeout, because the lookup runs
  on the main thread that also serves the event tap.

## Consequences

- Never taking focus was verified by hand at G2 in TextEdit, a terminal and an Electron
  app. Nothing automated guards it, so the live revision preview needs the same check.
- Placement on a second display is verified only by reading (see
  [0007](0007-known-gaps.md)).
