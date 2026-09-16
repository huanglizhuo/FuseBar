# FuseBar 1.1.0

FuseBar now speaks English, Simplified Chinese, Japanese, French, and Spanish. It follows your Mac’s preferred language list, including regional variants, and falls back to English when none match. Chinese variants use Simplified Chinese. Restart FuseBar after changing the system/app language.

This release also brings the expanded control panel:

- See up to two rows of running apps; open the full list with the overflow button. Pin favorites and manage their order.
- Open the app launcher, Mission Control, saved files/folders, and system settings from compact shortcuts.
- Select a sound output, mute supported devices, and adjust volume with immediate feedback and CoreAudio change notifications.
- Scan for Wi-Fi networks on request and connect to supported personal networks. Network names require optional location permission; no location coordinates are collected. Enterprise and other authentication open System Settings.
- View paired Bluetooth devices, with connection, pairing, and power controls delegated to System Settings.
- Smaller Personal Hotspot indicator and corrected monochrome menu bar rendering.
- Fixed network-name authorization messaging, missing system symbols, back navigation, and repeated menu open/close behavior.

The new README includes English native UI previews. Your data stays on your Mac; there are no ads, accounts, analytics, or subscriptions.

## Install

Download `FuseBar-1.1.0-macOS.zip`, extract it, and move FuseBar to Applications. Quit a running older version before replacing it. Requires macOS 14 or later; the universal app supports Apple Silicon and Intel.

The GitHub build is Developer ID signed, notarized by Apple, and stapled. `SHA256SUMS.txt` contains the download checksum.

## Scope and validation

32 automated tests pass, including language selection, catalog parity, and format placeholders. Native UI previews were checked across all five languages on macOS 26.6. Intel and older macOS runtime compatibility, every audio/Bluetooth device, and live Wi-Fi switching are not fully verified. System-reserved controls remain explicit system handoffs; FuseBar does not automatically hide other menu bar icons.

This is a GitHub-only release. The existing App Store submission remains unchanged and under review.
