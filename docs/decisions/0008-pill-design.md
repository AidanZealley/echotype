# 0008 The pill: a text-first layout with a level glow

Status: accepted, 2026-09-24 (overlay gate G1). Departs from the specification's Overlay
layout.

## Context

The specification lays the pill out in one row, left to right: level meter, transcript,
elapsed time, with the hint underneath. It asks for a meter of small vertical bars, "not
decorative waveform art". Aidan chose the design from variants over four rounds with the
`--hud-demo` launch. Three layouts came first: the specification's single row, a text-first
layout, and a pill whose bottom edge was the meter. He preferred the text-first layout but
wanted the more obvious level feedback of the third. The level feedback then went from a
bar on the edge to a glow behind the pill, then a glow inside it, then a choice of glow
forms, and finally opacity and placement.

## Decision

- Text first. A slim strip holds the bar meter, the phase word and elapsed time. The
  transcript sits below it in a larger font, up to two lines. The hint
  `⌥D stop · esc cancel` sits right-aligned at the foot. The pill is 420pt wide, Liquid
  Glass in a 22pt rounded rectangle.
- The bar meter stays as the specification describes: five small bars driven by RMS. It
  is flat and faint while starting, dimmed while paused, a spinner while transcribing and
  a red triangle on error.
- A blue wave glow sits inside the pill, clipped by its edge, hanging from the top edge.
  Its depth follows the recent level, from about 8% of the pill's height at silence to
  about 70% at full level, averaged over the last four levels so it swells rather than
  jitters. It is blurred and fades lighter downward. Its ripples move only while
  listening, and it flattens to a faint line when the user is quiet.
- Glow opacity: 0.4 listening, 0.25 and grey while starting, 0.15 and still while paused,
  gone once transcribing or failed. Aidan asked for it more subtle than the candidates
  twice. The values were then picked without him naming a number, and he raised nothing
  about them at G2.
- The transcript truncates from the left. Error text replaces it in red and truncates
  from the end, because the start of an error says what failed.
- Everything the pill shows comes from one value, `Pill`. `--hud-demo` and the live
  controller both drive it through the same `OverlayPanel` calls. The demo is a permanent
  part of the app.

## Consequences

- The glow's ripples move on their own while the user speaks. That is the waveform art
  the specification rules out, and Aidan accepted it. The bar meter is still the thing to
  read the level from.
- Tune the glow in `LevelGlow` and the meter mapping in `Overlay.level(rms:)`, and check
  both with `./scripts/run.sh --hud-demo` before dictating.
