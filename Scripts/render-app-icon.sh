#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
composer_tool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
icon_source="$PWD/Sources/MergeBar/AppIcon.icon"
icon_output="$PWD/docs/previews/app-icon"
mkdir -p "$icon_output"
for pair in Default:default Dark:dark ClearLight:clear-light ClearDark:clear-dark TintedLight:tinted-light TintedDark:tinted-dark; do
  rendition="${pair%%:*}"
  filename="${pair#*:}"
  "$composer_tool" "$icon_source" --export-image --output-file "$icon_output/$filename.png" \
    --platform macOS --rendition "$rendition" --width 1024 --height 1024 --scale 1
done
for size in 16 32 64 128 256; do
  "$composer_tool" "$icon_source" --export-image --output-file "$icon_output/default-$size.png" \
    --platform macOS --rendition Default --width "$size" --height "$size" --scale 1
done
