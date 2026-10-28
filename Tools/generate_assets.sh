#!/bin/zsh
# Regenerates every artwork and audio asset from source. Requires Xcode command-line
# tools (swiftc, afconvert) and Python 3 with Pillow (`pip3 install Pillow`) for the app icon.
#
#   ./Tools/generate_assets.sh
#
# Outputs:
#   CatchTheJewels/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png  (from assets/AppIconSource.jpeg)
#   CatchTheJewels/Resources/Assets.xcassets/BrandMark.imageset/BrandMark*.png     (launch screen + splash)
#   CatchTheJewels/Resources/Sounds/*.caf, music_royal_loop.m4a
set -euo pipefail

ROOT="${0:A:h:h}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ASSETS="$ROOT/CatchTheJewels/Resources/Assets.xcassets"
SOUNDS="$ROOT/CatchTheJewels/Resources/Sounds"

echo "› Compiling artwork renderer"
swiftc -O -o "$WORK/AssetRenderer" \
  "$ROOT/Tools/AssetRenderer/main.swift" \
  "$ROOT/CatchTheJewels/Artwork/ArtworkPainter.swift" \
  "$ROOT/CatchTheJewels/Models/FallingObjectKind.swift"

echo "› Rendering artwork preview (verifies the shared painter compiles on macOS)"
"$WORK/AssetRenderer" "$WORK/art"

echo "› Building app icon from assets/AppIconSource.jpeg"
python3 -I "$ROOT/Tools/make_app_icon.py" "$ROOT/assets/AppIconSource.jpeg" "$ASSETS/AppIcon.appiconset/AppIcon-1024.png" \
  --brand-mark "$ASSETS/BrandMark.imageset"

echo "› Synthesizing audio"
python3 "$ROOT/Tools/synthesize_audio.py" "$WORK/audio"
mkdir -p "$SOUNDS"
for wav in "$WORK"/audio/sfx_*.wav; do
  name="$(basename "$wav" .wav)"
  afconvert -f caff -d LEI16 "$wav" "$SOUNDS/$name.caf"
done
afconvert -f m4af -d aac -b 128000 "$WORK/audio/music_royal_loop.wav" "$SOUNDS/music_royal_loop.m4a"

echo "✓ Assets regenerated"
