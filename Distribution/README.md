# Release workflow

FuseBar is free. GitHub releases use Developer ID signing and notarization; Mac App Store distribution is being resumed with the `com.clothpath.fusebar` identifier. The old App Store entry (6812443369, `com.clothpath.mergebar`) cannot change its bundle ID after an uploaded build and is not the destination for new builds. Signing uses the developer's local Xcode account and Keychain. No Apple private key or notarization password is stored in GitHub.

## Self-hosted build and release

The repository runner `fusebar-mac-arm64` runs on the maintainer's Mac with label `fusebar-release`. Its launch agent lives under `~/Library/LaunchAgents`; runner files are in `~/actions-runner-fusebar`. The Mac must be awake, the user session active, and Xcode's account and signing Keychain available. Xcode, XcodeGen, asc and gh must already be installed. Do not run untrusted pull-request code on this signing machine.

Commit and push the version bump, generated project and release notes to `main`, then run **Actions → Build and release on Mac**. Only the repository owner can start its release job, and only from `main`. Jobs are serialized to avoid overlapping use of signing resources within this repository.

- `app-store`: checks the `APP_STORE_APP_ID` repository variable against `project.yml`, tests, archives and uploads using `Distribution/AppStore.plist`. Set the variable to the newly created app record's numeric ID. A successful upload is not App Review submission or public release; select the processed build and complete metadata/review separately.
- `github`: runs `Scripts/release.sh` to test, archive, notarize and create the tag and draft ZIP, then explicitly dispatches **Verify and publish release**. This explicit dispatch is necessary because tag pushes made with `GITHUB_TOKEN` do not trigger push workflows. The hosted Mac independently checks signature, notarization, version and architectures before publication.

The workflow can also be started with `gh workflow run build-release.yml --ref main -f channel=app-store` or `-f channel=github`. Use a new version/build number for each new upload. If GitHub verification fails after a draft exists, retry `release.yml` with that tag; do not rebuild or replace an already published tag.

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

This uploads using the signed-in Xcode account. The new app record must use `com.clothpath.fusebar`. In App Store Connect, select the processed build and complete Add for Review. Review submission and public App Store release are separate steps.

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
