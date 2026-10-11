# Kokoro eSpeak frontend comparison

Accepted for productionization by Aidan on 9 October 2026 after listening to the
comparison app: "Output is really good! I'd be happy to pick this as the final choice
to productionise". The implementation and packaging described below are still the
trial. The [productionization spec](../specs/local-models-productionization.md)
defines the remaining work before shipping.

The app keeps the existing Kokoro v1.0 Core ML weights, Heart and Emma voice packs,
speed controls and speech stream. Written-form normalization and the explicit clock
a.m./p.m. preparation remain. eSpeak NG replaces FluidAudio's English word lookup
and neural G2P for synthesis. The always-weak article override is removed.

The web demo embeds the `webml-community/kokoro-web` Space. Its deployed worker
uses eSpeak NG on punctuation-separated phrases, then an older Kokoro ONNX model.
This trial uses the same phrase-aware frontend approach, with English phonemes
adapted to the newer model's Misaki alphabet. The conversion follows the upstream
Misaki eSpeak fallback's phoneme mappings. It does not reproduce the demo's model.

Sources:

- https://webml-community-kokoro-web.static.hf.space/assets/worker-D_5WLGI4.js
- https://github.com/hexgrad/misaki/blob/main/misaki/espeak.py
- https://github.com/espeak-ng/espeak-ng-spm

The Swift dependency is pinned at `fd28f6460cc4cdf631528c8e2f7bd825747aac5c`.
One actor serializes eSpeak's process-global initialization, accent selection and
conversion. Phonemes are split at word or punctuation boundaries to stay within
the model's 510 Unicode scalar limit. Cancellation is checked between model calls.

## Packaging and reproduction

SwiftPM bundles about 64 MB of dictionary and phoneme sources. The comparison app
instead packages English dictionary and phoneme tables compiled from that pinned
package. No eSpeak model download or Homebrew installation is required.

The development fallback compiles English data into
`~/Library/Application Support/EchoType/Models/espeak-english-trial-fd28f646/`.
It uses the same model root as the rest of the local provider. The app copies its
bundled compiled data there on first use if that trial directory is absent.

To reproduce the small comparison bundle, first run the native frontend tests to
prepare the compiled data, then build:

```sh
swift test --filter 'KokoroEnglishFrontendTests|KokoroTextTests|KokoroSpeechTests'
ECHOTYPE_ESPEAK_COMPILED_DATA="$HOME/Library/Application Support/EchoType/Models/espeak-english-trial-fd28f646/espeak-ng-data" \
  scripts/build-app.sh release .build/espeak-front-end-trial/EchoType.app
codesign --verify --deep --strict .build/espeak-front-end-trial/EchoType.app
```

This staging option is for the comparison. A permanent adoption should generate
the compiled resources deterministically during the build, eliminate the runtime
compiler and source-bundle fallback, and account for these files in model removal.
FluidAudio initialization still prepares its original G2P assets. The trial does
not claim a reduction in their memory use or model download size.

## Verification and measurements

- Seven focused tests passed, including both accents, consonant/vowel sound
  distinctions, literal "thee", phoneme limits, clocks and speech cancellation.
- The release app built and passed strict signature verification.
- Disk usage was 72,840 KiB for this app versus 69,964 KiB for the previous
  always-weak-article trial. The compiled pronunciation data occupies 2,312 KiB
  separately in the model root. These are allocated disk sizes, not compressed
  download sizes. The new app also includes the recently merged main fixes.
- A release synthesis smoke run generated both pronunciation and numbers passages
  twice through Heart, with zero recorded stream violations. Real-time factor was
  0.06; first audio ranged from 331 to 730 ms after model readiness. This is not
  a controlled speed comparison against the previous frontend.
- Raw smoke-run data and WAVs are in
  `~/Library/Application Support/EchoTypeBench/runs/20261009T111948Z-local/`.

The existing bench was used only for this smoke check. Productionization will record
remaining measurements and retire it before merging. The separate three-tier testing
specification does not require retaining the bench.

## Listening decision and licensing

Aidan's listening comparison confirmed this frontend as the production choice.
After replacing the trial packaging and removing obsolete assets, repeat the signed-app
checks for "the apple", "the hour", "the university", literal "thee", numbers, clocks
and a longer reading. The acceptance of the audio does not complete those lifecycle
and packaging checks.

The app includes the eSpeak GPLv3 licence in `Contents/Resources/Licenses/`.
This is a local personal evaluation, not a public release. The repository's licence
has not been changed. Before distributing an adopted build, settle GPL-compatible
licensing for the combined program and provide its corresponding source, build
instructions and notices. GPL permits commercial use as well as personal use;
an adopted GPL release cannot impose a personal-use-only restriction.
