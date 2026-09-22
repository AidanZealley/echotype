#!/usr/bin/env bash
# Builds, bundles, signs and (re)launches EchoType. The only supported way to run
# the app: TCC grants key off the bundle identifier and the stable "EchoType Dev"
# signature, so every build must go through this path to keep its permissions.
set -euo pipefail

cd "$(dirname "$0")/.."

app=.build/EchoType.app

swift build

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/debug/EchoTypeApp "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"

codesign --force --sign "EchoType Dev" "$app"

# Wait for the old instance to exit, otherwise `open` just reactivates it.
pkill -x EchoTypeApp || true
while pgrep -x EchoTypeApp >/dev/null; do sleep 0.1; done

open "$app"
