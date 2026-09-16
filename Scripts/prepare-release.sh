#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Run from the intended release commit. Signing and Apple login stay in Keychain.
archive="${1:-$PWD/build/FuseBar.xcarchive}"
app="${2:-$PWD/build/DeveloperID/FuseBar.app}"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$archive/Products/Applications/FuseBar.app/Contents/Info.plist")
codesign --verify --deep --strict --verbose=2 "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=4 "$app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
mkdir -p build/release
asset="$PWD/build/release/FuseBar-${version}-macOS.zip"
[[ ! -e "$asset" ]] || { print -u2 "Asset already exists: $asset"; exit 1; }
ditto -c -k --sequesterRsrc --keepParent "$app" "$asset"
print "Prepared: $asset"
print "Upload to a draft release, then run the Verify and publish release Action."
