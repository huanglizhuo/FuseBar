#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Build a separate, unsigned render harness. Its bundle contains the production
# localizations; AppleLanguages is process-local and never changes system settings.
preview_root=$(mktemp -d /private/tmp/FuseBarPreview.XXXXXX)
trap 'rm -rf "$preview_root"' EXIT
preview_app="$preview_root/FuseBarPreview.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources"
cp -R Sources/FuseBar/Resources/*.lproj "$preview_app/Contents/Resources/"
cat > "$preview_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FuseBarPreview</string>
<key>CFBundleIdentifier</key><string>com.fusebar.readme-preview</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
</dict></plist>
PLIST
sources=(Sources/FuseBar/*.swift)
sources=(${sources:#Sources/FuseBar/FuseBarApp.swift})
xcrun swiftc -module-cache-path "$preview_root/modules" -o "$preview_app/Contents/MacOS/FuseBarPreview" "${sources[@]}" Scripts/render-readme-previews.swift
output="${1:-$PWD/docs/previews}"
for language in en zh-Hans ja fr es; do
  "$preview_app/Contents/MacOS/FuseBarPreview" "$output" -AppleLanguages "($language)"
done
