# Cleanup dependencies after Qwen speech removal

Status: dependency resolution complete, 2026-10-09. Combined validation is pending the
Parakeet and Kokoro investigations.

## Change

The productionization branch removes Qwen3-TTS and its MLX Audio Swift dependency. The
completed experiment remains on `spike/local-models`; downloaded speech assets are untouched.
Qwen3-4B cleanup remains supported.

Restore MLX Swift 0.32.3 and MLX Swift LM revision
`5e46681b2adcef2db158e7b949aeae3896778e23`, the pair used for the earlier cleanup measurements.
This is a return to a measured configuration, not an upgrade to the latest release.
Cleanup's cache creation now propagates the newer API's errors.

Remove the Qwen speech adapters, manifests, dedicated stream tests, candidate entries and
bench-only one-second cancellation delay. Keep the bench only through the remaining
productionization measurements, then retire it before merging. Whisper and SmolLM3 removal belong to the broader pruning pass.

## Evidence and remaining checks

`swift package resolve` succeeded. The lockfile removes MLX Audio Swift and changes only
the two MLX pins plus its origin hash. Source and test searches find no Qwen speech or
MLX Audio references in the active implementation.

After the investigations settle, run deterministic tests, release builds of the app and
bench, and a cleanup corpus pass with installed assets. Compare quality and cancellation
with the recorded earlier runs, accounting for current machine load. Also validate the
chosen combined set once model choices and remaining blockers are settled.
