# FuseBar 1.5.0

This update makes routine status work more selective and everyday app and audio controls clearer.

- The menu-bar image is regenerated only when its visible state changes. Tooltips and accessibility descriptions still receive updated network and device details.
- Battery changes use system notifications, while audio keeps its existing system listener. The three-second fallback remains, with fewer battery and audio reads between full refreshes.
- Installed-app search refreshes its catalog on demand, so newly installed or removed apps can appear without restarting FuseBar. Sound and Bluetooth results show both their category and the action Return performs.
- Running apps offer normal Quit. Force Quit requires a separate warning with Cancel as the default button. Hold Command to see the numbers for ⌘1–⌘9.
- Refreshing sound outputs keeps the existing list visible and does not block volume controls. Bluetooth audio connections show whether FuseBar is connecting, waiting for an audio channel, or switching the output.
- Diagnostic previews and copies withhold error text that could contain names or file paths. Actionable errors remain visible inside the app.

FuseBar remains free and local, with no accounts, ads, analytics or subscriptions.

## Install

Download `FuseBar-1.5.0-macOS.zip`, extract it, and move FuseBar to Applications. Quit an older version before replacing it. Requires macOS 14 or later; supports Apple Silicon and Intel.

## Validation

All 94 XCTest and 28 Swift Testing checks passed using the standard signed test workflow. Offscreen previews were generated in all five languages, with representative layouts inspected. These checks do not establish energy savings or verify live Bluetooth/audio routing, sleep/wake, or menu-bar readability on every display. Developer ID signing, notarization and independent release verification are required by the GitHub publication workflow.
