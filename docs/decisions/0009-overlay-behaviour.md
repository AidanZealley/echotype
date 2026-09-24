# 0009 How the overlay behaves during a session

Status: accepted, 2026-09-24 (overlay gate G2). Supersedes the error surface in
[0006](0006-api-key-and-error-surface.md).

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
- A click is taken in the panel's `sendEvent` and not forwarded, so no SwiftUI view
  handles it.
- A click commits a running session and does nothing otherwise. The specification says
  a click "does the same as Opt+D". Here a click never starts a session, so clicking a
  red error pill or a fading pill never opens the microphone. The second click of a
  double click does nothing.
- The event tap callback only changes the controller's phase, which the consume decision
  reads, and starts tasks for everything else. The next key event is still judged against
  the right phase.
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
  -50 dBFS (empty) to -20 dBFS (full), so ordinary speech sits around two thirds.
- The pill goes on the screen containing the centre of the frontmost app's focused
  window, read through Accessibility. It falls back to the screen under the mouse, then
  the main screen. Each Accessibility read has a 0.25s timeout, because the lookup runs
  on the main thread that also serves the event tap.

## Consequences

- Never taking focus was verified by hand at G2 in TextEdit, a terminal and an Electron
  app. Nothing automated guards it, so any change to the panel or its click handling
  needs the same check.
- Placement on a second display is verified only by reading (see
  [0007](0007-known-gaps.md)).
