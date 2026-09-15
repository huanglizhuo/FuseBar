# FuseBar

**Essential Mac status, together in one menu bar icon.** Free, native, and local. Requires macOS 14 or later.

![FuseBar app icon](docs/previews/app-icon/default-256.png)

FuseBar combines battery level, Wi-Fi status, and a centered priority indicator in a compact menu bar entry. Click it to see battery, Wi-Fi, Bluetooth, and audio details or adjust supported output devices' volume. No account, ads, subscription, or analytics.

## Download and use

Download a packaged build from [GitHub Releases](https://github.com/huanglizhuo/MergeBar/releases). Release availability and signing details are listed with each version. The Mac App Store version is being prepared.

Move FuseBar to Applications and launch it. **FuseBar lives in the menu bar and does not show a Dock icon.** Click its ring to open the panel and first-use guide. The current app interface is Simplified Chinese.

You can manually hide redundant system icons in System Settings → Menu Bar (Control Center on older macOS versions). FuseBar does not automatically hide, move, or modify other apps' menu bar items.

## Features

- Battery ring with charging, low-battery, unknown, and no-internal-battery states.
- Wi-Fi connection and signal strength, with an optional network name.
- A stable, centered bottom indicator: critical battery → disconnected Wi-Fi → low battery → charging → mute. Other details remain in the panel.
- Optional Bluetooth power and connected paired-device details; no scanning or pairing.
- Output volume and mute status, plus volume adjustment where supported by the device.
- Native SwiftUI/AppKit panel, monochrome menu bar rendering, saved preferences, and user-controlled launch at login.
- An original layered Liquid Glass app icon built with Apple's Icon Composer.

## Privacy

Status information stays on your Mac. Bluetooth permission is optional. macOS location permission is only requested when you choose to show the Wi-Fi network name; FuseBar does not request location coordinates or start location updates. Basic features remain available when optional permissions are declined.

Read the [privacy policy](docs/PRIVACY.md). Report issues through [GitHub Issues](https://github.com/huanglizhuo/MergeBar/issues).

## Build

Open `FuseBar.xcodeproj` and select the **FuseBar** scheme. Configure your signing team for signed builds. To build locally without a developer certificate:

```sh
xcodebuild -project FuseBar.xcodeproj -scheme FuseBar -configuration Debug \
  -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build
open build/Build/Products/Debug/FuseBar.app
```

For the configured development team:

```sh
zsh Scripts/build.sh
zsh Scripts/test.sh
```

`project.yml` is the source of truth for the project. Run `xcodegen generate` after adding files or changing build configuration. Building the committed Xcode project does not require XcodeGen. There are no third-party runtime dependencies.

## Limitations and validation

Status refreshes approximately every three seconds, pauses during sleep, and resumes after wake. Wi-Fi association does not establish internet reachability. Bluetooth enumeration may not include every BLE peripheral. External audio devices may not support software volume control; changing volume does not automatically unmute them.

See [validation notes](docs/VALIDATION.md) for observed results and remaining compatibility checks. Rendered fixture galleries are design previews, not evidence of live hardware behavior. Do not distribute locally signed development builds as notarized releases.

## Project notes

- [Product and implementation plan](docs/PLAN.md)
- [Distribution checklist](docs/APP_STORE_RELEASE.md)
- [App icon source and design](Design/AppIcon/DESIGN.md)
- [Original PRD](docs/Original-PRD.md)

Previously named MergeBar; the GitHub repository URL and registered bundle identifier are retained for continuity. The visual layout was inspired by [CircleStatusBar](https://github.com/artemnovichkov/CircleStatusBar). FuseBar's drawing and system integration are independently implemented; no reference-project code or media is included.
