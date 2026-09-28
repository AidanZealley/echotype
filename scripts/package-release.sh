#!/usr/bin/env bash
# Produces a signed app and DMG in .build/release without installing or launching either.
set -euo pipefail

cd "$(dirname "$0")/.."

version=$(plutil -extract CFBundleShortVersionString raw -o - Resources/Info.plist)
output=.build/release
app="$output/EchoType.app"
image="$output/EchoType-$version.dmg"

./scripts/build-app.sh release "$app"

contents=$(mktemp -d .build/EchoType-dmg-XXXXXX)
trap 'rm -rf "$contents"' EXIT
cp -R "$app" "$contents/"
ln -s /Applications "$contents/Applications"
hdiutil create -volname EchoType -srcfolder "$contents" -format UDZO -ov "$image"

echo "Created $app and $image"
