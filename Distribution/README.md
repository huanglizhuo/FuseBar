# Release workflow

FuseBar is free on both channels. Signing and notarization use the developer's local Xcode account and Keychain. GitHub Actions independently verifies a prepared, notarized ZIP on a hosted Mac and publishes the draft release. No Apple certificate, private key, or notarization password is stored in GitHub.

## Build and sign locally

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`; run `xcodegen generate`, build and test.
2. Commit the release code and create the matching version tag (e.g. `v1.0`).
3. Archive:

```sh
xcodebuild -project FuseBar.xcodeproj -scheme FuseBar -configuration Release \
  -archivePath build/FuseBar.xcarchive -allowProvisioningUpdates archive
```

## App Store

```sh
xcodebuild -exportArchive -archivePath build/FuseBar.xcarchive \
  -exportOptionsPlist Distribution/AppStore.plist -exportPath build/AppStore \
  -allowProvisioningUpdates
```

This uploads using the signed-in Xcode account. In App Store Connect, select the processed build and complete Add for Review. Review submission and public App Store release are separate steps.

## GitHub

```sh
xcodebuild -exportArchive -archivePath build/FuseBar.xcarchive \
  -exportOptionsPlist Distribution/Notarize.plist -exportPath build/Notarization \
  -allowProvisioningUpdates
xcodebuild -exportNotarizedApp -archivePath build/FuseBar.xcarchive \
  -exportPath build/DeveloperID
zsh Scripts/prepare-release.sh
```

Wait for notarization to complete before exporting; a pending result is not permission to publish an unsigned fallback. The ZIP preserves the app signature and stapled ticket. Users unzip it, move FuseBar.app to Applications, and launch it from there.

Create a draft release with the existing tag and the ZIP, then run **Actions → Verify and publish release → Run workflow**, entering the tag. The Action verifies the Developer ID Team, bundle ID, version, universal architectures, signature and stapled notarization ticket. Only after all checks pass does it attach SHA256SUMS.txt and publish the release.

Example, after creating and pushing the intended release tag:

```sh
gh release create v1.0 build/release/FuseBar-1.0-macOS.zip \
  --draft --verify-tag --title 'FuseBar 1.0' --notes-file Distribution/RELEASE_NOTES.md
gh workflow run release.yml -f tag=v1.0
```

This is intentionally a local-build / hosted-verification pipeline. A future fully hosted signing pipeline would require separately provisioning Apple signing and notarization secrets.
