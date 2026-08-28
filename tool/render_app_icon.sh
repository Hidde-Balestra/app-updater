#!/usr/bin/env bash
# Regenerates the Android launcher icon PNGs from assets/icon/app_icon.svg.
# Requires rsvg-convert (librsvg2-bin on Debian/Ubuntu).
#
# Usage: tool/render_app_icon.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="assets/icon/app_icon.svg"
RES="android/app/src/main/res"

declare -A sizes=(
  [mdpi]=48
  [hdpi]=72
  [xhdpi]=96
  [xxhdpi]=144
  [xxxhdpi]=192
)

for density in "${!sizes[@]}"; do
  size="${sizes[$density]}"
  out="$RES/mipmap-$density/ic_launcher.png"
  mkdir -p "$(dirname "$out")"
  rsvg-convert -w "$size" -h "$size" "$SRC" -o "$out"
  echo "wrote $out (${size}x${size})"
done
