# Kokoro pronunciation investigation

This records the original FluidAudio frontend investigation. After listening rejected
the always-weak article override, the current branch moved to an eSpeak comparison.
See [the comparison notes](kokoro-espeak-comparison.md) for the implementation,
packaging, verification and outstanding listening decision.

Investigated on 2026-10-09 against FluidAudio revision
`0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7` and EchoType's installed,
pinned US lexicon. No model downloads or playback were needed for this
investigation. Listening validation remains outstanding.

## The article "the"

FluidAudio resolves each word independently. Its installed lexicon contains
`the -> ði`, so both "the apple" and "the banana" receive the long-vowel
article. The same lexicon maps literal "thee" to exactly the same phonemes.
This explains the recorded "thee" complaint without requiring a voice-weight
change.

The upstream [Misaki English frontend](https://github.com/hexgrad/misaki/blob/main/misaki/en.py)
uses following sound context. It returns `ði` before a vowel and `ðə`
otherwise. Following spelling is insufficient: "the hour" begins with a vowel
sound, while "the university" begins with a consonant sound. Punctuation can
end that context.

FluidAudio's public `phonemes(for:)` does not expose source-token alignment.
Replacing standalone `ði` in its result would also change "thee". A global
custom-lexicon entry for "the" would incorrectly force the weak form before
vowels. Neither workaround is implemented.

Preferred fix: change FluidAudio's English phonemizer to resolve tokens and
retain their original text, then apply the article rule using the next
resolved word's first speech sound, stopping at pause punctuation. Add tests
for consonants, vowel sounds, "hour", "university", literal "thee", quotation
marks and punctuation. Keep `synthesizeDetailed` as the public synthesis path
so normalization and its 510-scalar phoneme chunking remain intact.

This requires an upstream change and a pin update, or a bounded FluidAudio
fork. The current public API cannot implement the correct contextual rule
without rebuilding part of its frontend in EchoType. No fork or dependency
change was made here.

## Dotted meridiems

The bundled NeMo normalizer converts `11:45 a.m.` to
`eleven forty five AM`. The installed case-sensitive lexicon then maps `AM`
to `æm`, the ordinary word "am". That explains the observed "ahm" reading.
`PM` has a different dictionary pronunciation, but using explicit letter
names for both meridiems avoids this asymmetric treatment.

`KokoroText.prepare` now spaces the letter names only after a valid explicit
12-hour clock: `11:45 a.m.` becomes `11:45 A M.`. It preserves the clock,
whitespace and final period, handles either case and leading-zero hours, and
leaves standalone abbreviations, uppercase prose, invalid clocks and
identifier-shaped prefixes untouched. There is no dot between the spoken
letter names.

The parent integrated this in `KokoroModel.speak`:

```swift
return KokoroSpeech(text: KokoroText.prepare(request.text)) { [manager] utterance in
```

Keep the existing `synthesizeDetailed` call unchanged. Applying the helper
before sentence splitting prevents either dotted abbreviation from being
split before it can be prepared. Voice, speed, cancellation and runtime
phoneme chunking are unchanged.

Two focused tests cover preparation, preservation of ambiguous text and the
prepared result surviving the actual NeMo frontend. Run with:

```sh
swift test --filter KokoroTextTests
swift test --filter KokoroSpeechTests
```

Swift builds were left to the parent while it coordinated dependency changes.
The parent has started the focused tests; their result is pending.
`git diff --check` passed for this work.

## Numbers and units

I linked a temporary C probe against the already-present NeMo static library,
calling the same `nemo_tn_fst` entry point used by FluidAudio. It produced:

| Written input | Normalized output |
| --- | --- |
| `3 Oct 2026` in the recorded passage | `the third of october twenty twenty six` |
| `16 GB` | `sixteen GB` |
| `2.5x` in the recorded passage | `two point five x` |
| `40%` | `forty percent` |
| `Use localhost on port 5173.` | `Use localhost on port five thousand one hundred and seventy three.` |
| `3.14` | `three point one four` |
| `2026-10-03` | `october third twenty twenty six` |
| `At 11:45 A M. and 01:05 P M. we read the report.` | `At eleven forty five A M. and one o five P M. we read the report.` |

The recorded "five thousand four hundred and seventy three" for 5173 is not
explained by text normalization. Inspect emitted phonemes and listen again
with the final build before changing number handling.

GB is absent from both installed lexicons. FluidAudio spells unknown ASCII
all-caps initialisms as letter names, so "jee bee" is expected. Expanding it
to "gigabytes" is a separate context-sensitive unit policy, not a number
conversion defect. Blind replacements would mishandle names and other uses.
Likewise, general acronym expansion or forced pronunciations for SwiftUI,
macOS, pnpm and Vite would require an explicit pronunciation policy. No
corpus-specific entries or new number grammar were added.

## Final listening checks

After parent integration, compare dotted meridiems at the beginning, middle
and end of sentences through Heart. Include a longer reading and confirm
that phrase boundaries remain natural. Capture runtime `normalizedText` and
`phonemes` when diagnosing any remaining number errors.

The article fix remains unresolved. Decide whether its audible cost justifies
an upstream contribution or maintained fork before considering pronunciation
work complete. Broader unit and technical-name policies remain separate
product decisions.
