#!/usr/bin/env bash
# Builds and signs an app bundle without installing or launching it.
# Usage: build-app.sh <debug|release> <output app path>
set -euo pipefail

cd "$(dirname "$0")/.."

configuration=$1
app=$2

swift build -c "$configuration" --product EchoTypeApp

staged=$(mktemp -d .build/EchoType-XXXXXX)
trap 'rm -rf "$staged"' EXIT
mkdir -p "$staged/EchoType.app/Contents/MacOS" "$staged/EchoType.app/Contents/Resources"
bin=$(swift build -c "$configuration" --show-bin-path)
cp "$bin/EchoTypeApp" "$staged/EchoType.app/Contents/MacOS/"
cp Resources/Info.plist "$staged/EchoType.app/Contents/"
cp Resources/AppIcon.icns "$staged/EchoType.app/Contents/Resources/"

# Dependencies ship their resources as bundles beside the executable, such as MLX's compiled
# Metal shaders. Bundle.module finds them only in Contents/Resources, and a missing one fails at
# the first use rather than at build time, so every bundle is staged before signing.
cp -R "$bin"/*.bundle "$staged/EchoType.app/Contents/Resources/"

# The same hardened runtime and microphone entitlement apply to local and release builds.
# Developer ID signing can replace the default identity when one is available.
signing_identity=${ECHOTYPE_SIGNING_IDENTITY:-Apple Development}
codesign --force --options runtime --entitlements Resources/EchoType.entitlements \
  --sign "$signing_identity" "$staged/EchoType.app"

rm -rf "$app"
mkdir -p "$(dirname "$app")"
mv "$staged/EchoType.app" "$app"
