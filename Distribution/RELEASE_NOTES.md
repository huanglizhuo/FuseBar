# FuseBar 1.4.1

FuseBar now explains exactly why macOS asks for location access: to display your connected Wi-Fi name and show nearby networks when you open the Wi-Fi panel.

- Clearer permission prompts in English, Simplified Chinese, Japanese, French and Spanish.
- The Wi-Fi panel explains that permission is optional, geographic location is not read, and network names remain on your Mac.
- Battery and audio features remain available without location permission.

FuseBar remains free and local, with no accounts, ads, analytics or subscriptions. A new Mac App Store submission is being prepared; this release does not mean App Store approval.

## Install

Download `FuseBar-1.4.1-macOS.zip`, extract it, and move FuseBar to Applications. Quit an older version before replacing it. Requires macOS 14 or later; supports Apple Silicon and Intel.

## Validation

The local build and all 83 XCTest plus 26 Swift Testing checks passed. This update changes permission text, not the permission request or Wi-Fi scanning implementation. New App Store signing and review are verified separately from the GitHub release.
