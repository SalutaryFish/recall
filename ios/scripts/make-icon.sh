#!/usr/bin/env bash
# Renders the app icon PNGs (opaque, 1024×1024) from their SVG sources.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../Recall/Resources/Assets.xcassets/AppIcon.appiconset"
for name in AppIcon AppIcon-Dark; do
    magick -background none -density 96 "$here/icon/$name.svg" -resize 1024x1024 \
        -alpha remove -alpha off -strip "PNG24:$out/$name.png"
done
ls -l "$out"
