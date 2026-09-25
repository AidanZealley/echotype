#!/usr/bin/env bash
# Builds, bundles, signs and (re)launches EchoType. The only supported way to run
# the app: TCC grants key off the bundle identifier and signing identity, so every
# build must go through this path to keep its permissions.
# Arguments are passed to the app, for example `./scripts/run.sh --hud-demo`.
set -euo pipefail

cd "$(dirname "$0")/.."

app=.build/EchoType.app

swift build

# Stop the old instance before replacing its bundle. Replacing the bundle under a running
# instance leaves Launch Services with a stale record for it, and `open` then fails with
# error -600. Waiting for the exit also stops `open` from just reactivating the old one.
pkill -x EchoTypeApp || true
while pgrep -x EchoTypeApp >/dev/null; do sleep 0.1; done

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/debug/EchoTypeApp "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"

# A unique local Apple Development identity is selected by default. Set the variable
# to a full certificate name or SHA-1 hash if more than one is installed.
signing_identity=${ECHOTYPE_SIGNING_IDENTITY:-Apple Development}
codesign --force --sign "$signing_identity" "$app"

open "$app" --args "$@"
