# FuseBar 1.3.0

Search now does more than open apps, and the panel gets you back to work faster.

- **Search finds the right thing first.** Results are ranked, with exact and prefix matches on top, so "sa" opens Safari instead of Messages. Apps are also found by their English file or bundle name (Terminal for 终端, "vscode"), by initials ("vsc"), and by pinyin ("wx" or "weixin" for 微信).
- **Search controls your devices.** Type a sound output to switch to it, a paired Bluetooth device to connect or disconnect it, an input source to switch to it, a project to open it, or a System Settings pane such as Displays or Focus. Each result says what Return will do, and device actions show their progress and verified result in the side menu.
- **A faster app grid.** The app you opened FuseBar from moves to the last slot, so the first slot is the app you used before it. ⌘1–⌘9 open the first nine apps, and icons stay put while the panel is open.
- **Projects open where you code.** Choose Finder, Visual Studio Code, Cursor, Zed, Xcode, Terminal, or any other app to open each project folder.
- **A Settings window.** Settings and the project editor moved out of the panel into their own window, with General and Projects tabs. Diagnostics shows a summary without Wi-Fi, device, file, or project names that you can copy into a bug report, and a link points to the latest release. FuseBar never checks for updates in the background.
- **More detail where it helps.** The battery menu shows the system's estimate of time remaining or time to full charge, and whether Low Power Mode is on. When Wi-Fi is associated but macOS reports no usable network on it, FuseBar says so instead of showing a plain connection.
- **A first-run guide that gets you started.** Record the quick-open shortcut and learn search right in the guide.
- **Fixed:** on a fresh install, Get started did not close the first-run guide.
- The System controls page was removed; its System Settings shortcuts are now in search.

FuseBar stays free and local: no accounts, ads, analytics, or subscriptions. It is distributed through GitHub releases and is not published on the Mac App Store.

## Install

Download `FuseBar-1.3.0-macOS.zip`, extract it, and move FuseBar to Applications. Quit a running older version before replacing it. Requires macOS 14 or later; the universal app supports Apple Silicon and Intel.

## Validation

76 XCTest and 25 Swift Testing checks pass, including new tests for search ranking, aliases and pinyin, device search actions, ⌘-number shortcuts, the first-run guide, battery estimates, and the Wi-Fi state. Previews were rendered in all five languages on macOS 26.7. Intel Macs, macOS 14 and 15, and live audio or Bluetooth switching through search have not yet been verified on hardware.
