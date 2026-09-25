#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from Resources/Logo.png, a 1024px square logo on a
# white background. The logo is drawn onto a white continuous-corner rounded rectangle on
# Apple's macOS icon grid (824px body, 100px transparent margin), then written at every
# size an .icns needs. Run it after changing the logo and commit both files.
set -euo pipefail

cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

swift - Resources/Logo.png "$work/master.png" <<'SWIFT'
import AppKit
import SwiftUI

let canvas: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
// The logo's artwork runs close to its own edges, so it is drawn a little smaller than
// the body to leave breathing room inside the rounded rectangle.
let logoSize: CGFloat = 760

let logo = NSImage(contentsOfFile: CommandLine.arguments[1])!
let context = CGContext(
  data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpace(name: CGColorSpace.sRGB)!,
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

context.addPath(RoundedRectangle(cornerRadius: 185.4, style: .continuous).path(in: body).cgPath)
context.clip()
context.setFillColor(.white)
context.fill(body)
let inset = (canvas - logoSize) / 2
context.interpolationQuality = .high
context.draw(
  logo.cgImage(forProposedRect: nil, context: nil, hints: nil)!,
  in: CGRect(x: inset, y: inset, width: logoSize, height: logoSize))

let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
SWIFT

iconset=$work/AppIcon.iconset
mkdir "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$work/master.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$work/master.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
