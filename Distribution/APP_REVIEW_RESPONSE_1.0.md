# FuseBar 1.0 (1) — App Review response draft

Checked: 2026-10-19 (Asia/Singapore), using asc 0.18.6 and the signed-in App Store Connect page. **Not sent.**

## Verified status

- App 6812443369: FuseBar, bundle ID `com.clothpath.mergebar`.
- Version 1.0 (1): `REJECTED`; submission `d8d7295d-4b20-49d4-acce-7ec60e472361`: `UNRESOLVED_ISSUES`.
- Apple review date: September 17, 2026; device: MacBook Air (15-inch, M3, 2024).
- Only listed issue: Guideline 2.4.5(i). Explain how and where `com.apple.security.personal-information.location` is used. Apple says supplying this information does not require a new binary. If the entitlement is unnecessary, remove it and upload an updated binary instead.
- CLI readiness checks pass for linked valid build, English metadata, pricing and review contact. Three desktop screenshots are COMPLETE. Passing these checks does not resolve the rejection or establish functional correctness.
- Existing review notes mention optional Wi-Fi name access but omit its exact UI path and the condition under which the button appears.

## Reply draft

Hello App Review Team,

Thank you for reviewing FuseBar. The `com.apple.security.personal-information.location` entitlement supports the optional display of the currently connected Wi-Fi network name (SSID) in the app's menu bar panel. The app reads the name using the public CoreWLAN `CWInterface.ssid()` API, for which macOS restricts access without location authorization.

To locate this feature in version 1.0 (1):

1. Connect the Mac to a Wi-Fi network and launch FuseBar.
2. Click the FuseBar ring icon in the macOS menu bar. The app does not have a Dock icon.
3. If the introductory screen appears, click “开始使用” (Get Started).
4. Below the Wi-Fi row, click “显示网络名称…” (Show Network Name…). This button appears when Wi-Fi is connected and the network name is unavailable. If the name is already available, the panel displays it and the permission button is not shown.
5. The app calls `CLLocationManager.requestWhenInUseAuthorization()` and refreshes Wi-Fi status when authorization changes. If permission was previously denied, the app explains how to enable it in System Settings > Privacy & Security > Location Services.

This permission is optional. FuseBar does not request geographic coordinates, start location updates, or upload network names. The network name is used locally for display. Battery and audio features remain available when permission is denied.

The entitlement is therefore used by this existing Wi-Fi name feature. Please let us know if any further information is needed to continue the review.

Thank you.

## Evidence and release limits

- Historical 1.0 source at `v1.0` and `e4dc0e8`: `PopoverView.swift` contains the conditional button, `StatusStore.swift` contains `requestNetworkName()`, `SystemReader.swift` reads `interface.ssid()`, and the entitlement is present. This is source inspection, not a fresh hardware test of the uploaded binary.
- Current project: 1.4.0 (9), bundle ID `com.clothpath.fusebar`. No 1.4.0 build is uploaded to this entry. Uploading a new version requires an App Store build matching `com.clothpath.mergebar`, validation and updated store materials.
- `asc iris resolution-center get` had no usable CLI cookie session; the signed-in Brave page supplied the rejection text. In asc 0.18.6, `iris resolution-center` exposes only `get`; sending the reply requires the website or another supported write interface.
- [Review message](https://appstoreconnect.apple.com/apps/6812443369/distribution/reviewsubmissions/details/d8d7295d-4b20-49d4-acce-7ec60e472361)
