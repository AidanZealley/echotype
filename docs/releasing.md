# Build and install a release

EchoType runs on macOS 26 or later. Its downloadable build is currently signed with
an Apple Development certificate and is not notarized. A Mac that downloads it may
block the first launch until its user chooses **Open Anyway** in System Settings →
Privacy & Security.

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` to the release version,
   such as `0.2.0`. Increment `CFBundleVersion` for every build you publish.
2. Run `./scripts/package-release.sh`. This creates `.build/release/EchoType.app` and
   `.build/release/EchoType-<version>.dmg`. It does not install or launch the app.
3. Test the DMG on another Mac or in a fresh macOS user account. Open it, drag
   EchoType into `/Applications`, and launch the installed copy. Check dictation,
   microphone permission, the hotkey, API key access, and launch at login. The
   `/Applications` folder is shared between accounts; `scripts/install.sh` asks for
   administrator access when another account owns the installed bundle.
4. Tag the commit as `v<version>` and attach the DMG to a GitHub Release with the same
   version. The Updates tab links to the latest published release.

To update manually, quit EchoType, download the new DMG, drag EchoType into
`/Applications`, choose **Replace**, and launch it again. Keep the bundle identifier
and signing identity stable across builds so macOS can recognize the replacement as
the same app. Moving to Developer ID signing later can cause a fresh permission or
Keychain prompt.

`ECHOTYPE_SIGNING_IDENTITY` selects a certificate if the keychain has multiple
matching identities. Developer ID distribution will also need a secure signing
timestamp and Apple notarization before publishing a DMG without the Gatekeeper
override.
