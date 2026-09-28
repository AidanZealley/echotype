# 0008 The pill: a text-first layout with a level glow

Status: accepted, 2026-09-24 (overlay gate G1). Live revision raised the transcript's
two-line cap to 184pt on 2026-09-27. The active microphone was added on 2026-09-28.
Departs from the specification's Overlay layout.

## Context

The specification lays the pill out in one row, left to right: level meter, transcript,
elapsed time, with the hint underneath. It asks for a meter of small vertical bars, "not
decorative waveform art". The author chose the design from variants over four rounds with the
`--hud-demo` launch. Three layouts came first: the specification's single row, a text-first
layout, and a pill whose bottom edge was the meter. He preferred the text-first layout but
wanted the more obvious level feedback of the third. The level feedback then went from a
bar on the edge to a glow behind the pill, then a glow inside it, then a choice of glow
forms, and finally opacity and placement.

## Decision

- Text first. A slim strip holds the bar meter, the phase word and elapsed time. The
  transcript originally sat below it in a larger font, up to two lines. The hint
  `⌥D stop · esc cancel` sits right-aligned at the foot. The pill is 420pt wide, Liquid
  Glass in a 22pt rounded rectangle.
- The bar meter stays as the specification describes: five small bars driven by RMS. It
  is flat and faint while starting, dimmed while paused, a spinner while transcribing and
  a red triangle on error. Its original bar dimensions remain. The meter and spinner use
  0.40 opacity, below the status text's 0.65.
- Each indicator keeps its natural width with an 8pt gap to its status label. Labels need
  not share a fixed starting position across phases.
- A blue wave glow sits inside the pill, clipped by its edge, hanging from the top edge.
  Its depth follows the recent level against the original one-line pill height, from
  about 8% of that height at silence to about 70% at full level. It keeps that scale as
  the transcript grows. The level is averaged over the last four samples so it swells
  rather than jitters. It is blurred and fades lighter downward. Its ripples move only
  while listening, and it flattens to a faint line when the user is quiet.
- Glow opacity: 0.4 listening, 0.25 and grey while starting, 0.15 and still while paused,
  gone once transcribing or failed. The author asked for it more subtle than the candidates
  twice. The values were then picked without him naming a number, and he raised nothing
  about them at G2.
- The transcript starts at one natural line and grows to a 184pt cap. At overflow it
  fades and clips older lines at the top and keeps the newest text at the bottom. About
  half of a clipped lowercase line remains visible near the top edge. Short
  transcripts stay opaque. The full transcript still goes to insertion. Error text
  replaces the preview in red and keeps its two-line limit, because the start says what
  failed. Dictation phases use the same status and hint layout. The layout has no scroll view
  or separate phase header.
- Provisional text, status, time, and hint share 0.65 opacity in the normal listening state.
- Everything the pill shows comes from one value, `Pill`. `--hud-demo` and the live
  controller both drive it through the same `OverlayPanel` calls. The demo is a permanent
  part of the app.
- During dictation, the footer shows the microphone that actually opened, opposite the
  hotkey hint. Bluetooth inputs use a headphones icon and other inputs use a mic icon.
  Names fit naturally up to 160pt, then clip with a right-edge fade. A fallback after
  a device disconnect updates the displayed input.

## Consequences

- The glow's ripples move on their own while the user speaks. That is the waveform art
  the specification rules out, and the author accepted it. The bar meter is still the thing to
  read the level from.
- Tune the glow in `LevelGlow` and the meter mapping in `Overlay.level(rms:)`, and check
  both with `./scripts/run.sh --hud-demo` before dictating.

## Reading update, 2026-09-27

Reading uses a 280pt wide, two-line pill. The top line holds the level meter, state
and elapsed time. The second gives the Space pause or resume and Escape stop hints.
There is no empty transcript line. A selection over the 60,000-character cap is read
without a notice; on 2026-09-28 Aidan removed the one that sat under the hints, since it
displaced them and a selection that long is rare. Aidan chose variant B of three demos. While reading
is paused, the meter and time retain 80% of their normal opacity and the displayed
time holds still. Reading errors keep the 280pt layout and show the error in place of
the shortcut hint.
