#!/usr/bin/env bash
# Builds, bundles, signs and (re)launches EchoType at a given path. `run.sh` and
# `install.sh` both go through here, so the development and installed bundles share one
# plist, bundle identifier and signing identity. TCC grants and the Keychain item key off
# those, so every build must come through this path to keep them.
# Usage: deploy.sh <debug|release> <app path> [app arguments...]
set -euo pipefail

cd "$(dirname "$0")/.."

configuration=$1
app=$2
shift 2

swift build -c "$configuration"

# Assemble and sign next to the build output, so a failed build or signature leaves the
# existing bundle untouched.
staged=.build/EchoType-$configuration.app
rm -rf "$staged"
mkdir -p "$staged/Contents/MacOS" "$staged/Contents/Resources"
cp "$(swift build -c "$configuration" --show-bin-path)/EchoTypeApp" "$staged/Contents/MacOS/"
cp Resources/Info.plist "$staged/Contents/"
cp Resources/AppIcon.icns "$staged/Contents/Resources/"

# A unique local Apple Development identity is selected by default. Set the variable
# to a full certificate name or SHA-1 hash if more than one is installed.
signing_identity=${ECHOTYPE_SIGNING_IDENTITY:-Apple Development}
codesign --force --sign "$signing_identity" "$staged"

# Stop every running copy, development or installed, before replacing its bundle.
# Replacing the bundle under a running instance leaves Launch Services with a stale record
# for it, and `open` then fails with error -600. Waiting for the exit also stops `open`
# from just reactivating the old one.
pkill -x EchoTypeApp || true
while pgrep -x EchoTypeApp >/dev/null; do sleep 0.1; done

rm -rf "$app"
mv "$staged" "$app"

open "$app" --args "$@"
