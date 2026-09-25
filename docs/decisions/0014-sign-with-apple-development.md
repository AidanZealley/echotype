# 0014 Sign with Apple Development

Status: accepted, 2026-09-25. Supersedes the certificate choice in
[0001](0001-build-and-sign-on-the-mac.md); its Mac build path and fixed bundle ID remain in force.

## Context

The spike used a self-signed `EchoType Dev` certificate to avoid ad hoc signatures changing
on each build. The project now uses each developer's Apple Development certificate,
which has a team ID. The signing choice in 0001 no longer describes `scripts/run.sh`.

## Decision

- `scripts/run.sh` selects the developer's Apple Development identity by default.
  If the keychain contains multiple matching certificates, set
  `ECHOTYPE_SIGNING_IDENTITY` to the chosen certificate's full name or SHA-1 hash.
  `security find-identity -v -p codesigning` lists available identities.
- The release `install.sh` must use the same selection as `run.sh`. Both bundles
  keep the identifier from `Resources/Info.plist` and use one signing identity
  per developer. Neither path uses ad hoc signing.

## Consequences

- Moving from another certificate or team changes the app's signing requirement.
  macOS may ask for permissions again after that change.
- The tested bundle's designated requirement named the Apple Development
  certificate as well as the bundle identifier. A team ID alone does not prove
  grants will survive a future certificate change.
- An older `EchoType Dev` certificate, if present, is no longer used by the scripts.
