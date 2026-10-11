# FuseBar 1.4.0

The ring now shows your battery percentage, and the whole icon turns red when the battery runs low.

- **Battery percentage on the ring.** The number sits in an opening at the top of the ring. The ring now fills in two halves: the left half up to 50%, then the right half from the top down. Turn the number off in Settings under Show in the ring › Battery percentage. It is hidden while the battery state is unknown and on Macs without a battery.
- **Battery level and charging at a glance.** With the number at the top, the bottom of the ring keeps showing the charging bolt and the other alerts. The bottom slot's battery percentage option was removed; if you had chosen it, the bottom returns to alerts and volume dots, and the number now appears at the top.
- **Red when the battery is low.** Below 20% on battery power, the whole icon turns red, in the menu bar and in the panel. Below 10%, the battery readout that appears beside the ring is red too. Plugging in restores the normal icon.

FuseBar stays free and local: no accounts, ads, analytics, or subscriptions. It is distributed through GitHub releases and is not published on the Mac App Store.

## Install

Download `FuseBar-1.4.0-macOS.zip`, extract it, and move FuseBar to Applications. Quit a running older version before replacing it. Requires macOS 14 or later; the universal app supports Apple Silicon and Intel.

## Validation

83 XCTest and 26 Swift Testing checks pass, including new tests for how the opened ring splits into halves, when the number shows, when the icon turns red, and the fallback for the retired bottom battery setting. The menu bar icon was checked live on macOS 26.7 at the real battery level and at simulated 76%, 15%, and 7% levels. A real discharge below 20%, Intel Macs, and macOS 14 and 15 have not yet been verified on hardware.
