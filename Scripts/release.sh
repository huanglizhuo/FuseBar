#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

tag="${1:-}"
notes="${2:-Distribution/RELEASE_NOTES.md}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { print -u2 "Usage: release.sh <tag> [notes-file]   (e.g. release.sh v1.2.0)"; exit 1; }
version="${tag#v}"

[[ -f "$notes" ]] || { print -u2 "Notes file not found: $notes"; exit 1; }

yml_version=$(sed -n "s/.*MARKETING_VERSION: '\(.*\)'.*/\1/p" project.yml | head -1)
[[ "$yml_version" == "$version" ]] || { print -u2 "project.yml MARKETING_VERSION is '$yml_version', does not match tag '$tag'. Run xcodegen generate after fixing."; exit 1; }

[[ -z "$(git status --porcelain)" ]] || { print -u2 "Working tree is not clean; commit or stash first."; exit 1; }

git fetch --tags origin
git rev-parse --verify "refs/tags/$tag" >/dev/null 2>&1 && { print -u2 "Tag $tag already exists."; exit 1; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse @{u})" ]] || { print -u2 "HEAD is not pushed to its upstream. Push the release commit first."; exit 1; }

print "==> Test"
zsh Scripts/test.sh

print "==> Archive"
xcodebuild -project FuseBar.xcodeproj -scheme FuseBar -configuration Release \
  -archivePath build/FuseBar.xcarchive -allowProvisioningUpdates archive

print "==> Upload for notarization"
xcodebuild -exportArchive -archivePath build/FuseBar.xcarchive \
  -exportOptionsPlist Distribution/Notarize.plist -exportPath build/Notarization \
  -allowProvisioningUpdates

print "==> Wait for notarization and export stapled app"
xcodebuild -exportNotarizedApp -archivePath build/FuseBar.xcarchive \
  -exportPath build/DeveloperID

print "==> Verify and package"
zsh Scripts/prepare-release.sh

asset="build/release/FuseBar-${version}-macOS.zip"

print "==> Create draft release (also creates tag $tag, triggering the verify-and-publish Action)"
gh release create "$tag" "$asset" --draft --title "FuseBar $version" --notes-file "$notes"

print "==> Release pipeline started."
print "The tag push triggers Actions → Verify and publish release, which verifies the"
print "Developer ID signature, notarization, version and architectures, then publishes."
print "Track it with: gh run watch"
