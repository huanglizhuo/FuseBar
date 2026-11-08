# FuseBar 1.5.1

This patch addresses the Wi-Fi confirmation panel reported in [issue #2](https://github.com/huanglizhuo/FuseBar/issues/2).

- Turning Wi-Fi off now shows confirmation inside the Wi-Fi submenu, so clicking Cancel or Turn Wi-Fi Off does not dismiss the menu as an outside click.
- Escape cancels the confirmation first; pressing it again closes the submenu. Closing and reopening the menu clears pending confirmation.
- Repeated confirmation submits only one power change, and a failed change can be retried with the error visible.

## Install

Download `FuseBar-1.5.1-macOS.zip`, extract it, and move FuseBar to Applications. Quit an older version before replacing it. Requires macOS 14 or later; supports Apple Silicon and Intel.

## Validation

The fix passed 95 XCTest and 28 Swift Testing checks on macOS 26.7. The regression test exercises real SwiftUI controls with simulated submenu presentation and Wi-Fi writes; the reporter's macOS 15.8.1 / M1 environment still needs confirmation. The GitHub publication workflow requires Developer ID signing, notarization and independent verification before publishing.
