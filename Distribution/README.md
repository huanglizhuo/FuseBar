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

With the version bumped in `project.yml` (and `xcodegen generate` run), the release commit pushed, and release notes written, the whole GitHub release is one local command:

```sh
zsh Scripts/release.sh v1.2.0
```

The script verifies the tag matches `MARKETING_VERSION` and that the tree is clean and pushed, then runs tests, archives, uploads for notarization, waits and exports the stapled Developer ID app, packages the ZIP (`Scripts/prepare-release.sh`), pushes the git tag and creates a **draft** release with it.

Pushing a matching tag any other way also triggers the Action, as long as the draft release with the ZIP already exists; `workflow_dispatch` with a tag input is the manual retry path.

The Action waits briefly for the draft to be visible, downloads the signed asset, and verifies the Developer ID Team, bundle ID, version, universal architectures, signature and stapled notarization ticket. Only after all checks pass does it attach SHA256SUMS.txt and publish the release.

The individual notarization and export steps (also used by the script) are:

```sh
xcodebuild -exportArchive -archivePath build/FuseBar.xcarchive \
  -exportOptionsPlist Distribution/Notarize.plist -exportPath build/Notarization \
  -allowProvisioningUpdates
xcodebuild -exportNotarizedApp -archivePath build/FuseBar.xcarchive \
  -exportPath build/DeveloperID
zsh Scripts/prepare-release.sh
```

This is intentionally a local-build / hosted-verification pipeline. A future fully hosted signing pipeline would require separately provisioning Apple signing and notarization secrets.

Versioned paths are also supported: `zsh Scripts/prepare-release.sh build/FuseBar-1.0.1.xcarchive build/DeveloperID-1.0.1/FuseBar.app`. The release helper verifies the exported version matches the archive before packaging.
