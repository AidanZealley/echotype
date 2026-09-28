#!/usr/bin/env bash
# Builds and (re)launches EchoType at a given path. `run.sh` and `install.sh` both
# go through here, so the development and installed bundles share one bundle and signer.
# Usage: deploy.sh <debug|release> <app path> [app arguments...]
set -euo pipefail

cd "$(dirname "$0")/.."

configuration=$1
app=$2
shift 2

# Build beside the output before stopping the running app. A failed build or signature
# leaves the installed bundle and running app alone.
staged=.build/EchoType-$configuration.app
"$(dirname "$0")/build-app.sh" "$configuration" "$staged"

# Stop every running copy, development or installed, before replacing its bundle.
# Replacing the bundle under a running instance leaves Launch Services with a stale record
# for it, and `open` then fails with error -600. Waiting for the exit also stops `open`
# from just reactivating the old one.
pkill -x EchoTypeApp || true
while pgrep -x EchoTypeApp >/dev/null; do sleep 0.1; done

rm -rf "$app"
mv "$staged" "$app"

open "$app" --args "$@"
