# FuseBar 1.2.0

FuseBar now speaks English, Simplified Chinese, Japanese, French, and Spanish. It follows your Mac's preferred language list, including regional variants, and falls back to English when none match. Restart FuseBar after changing the system/app language.

The home screen is now a calm running-apps grid:

- The app area shows only apps that are currently running, sorted by recent use — no pins, favorites or manual ordering to maintain. Open anything else from the main search, which covers both running and installed apps.
- Right-click a running app to hide, show, reveal it in Finder, or force quit it.
- A new onboarding guide appears the first time you open the panel, featuring an animated orb that demonstrates how the ring maps to battery, Wi-Fi, sound and Bluetooth. It plays once and respects Reduce Motion.

Under the hood, this release consolidates duplicated UI logic, cleans up dead code, and ships with a fully automated release pipeline: every published build is Developer ID signed, notarized by Apple, and verified again on GitHub before it goes live.

Your data stays on your Mac; there are no ads, accounts, analytics, or subscriptions.

## Install

Download `FuseBar-1.2.0-macOS.zip`, extract it, and move FuseBar to Applications. Quit a running older version before replacing it. Requires macOS 14 or later; the universal app supports Apple Silicon and Intel.
