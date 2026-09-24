import AppKit
import XCTest
@testable import FuseBar

@MainActor private final class TrackingPopover: NSPopover {
    var closeRequests = 0
    override func performClose(_ sender: Any?) { closeRequests += 1 }
}

@MainActor private final class FocusChangingPicker: NSOpenPanel {
    var duringPresentation: (() -> Void)?
    override func runModal() -> NSApplication.ModalResponse {
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        duringPresentation?()
        return .cancel
    }
}

final class PanelPresentationTests: XCTestCase {
    @MainActor func testClickingOutsideMenusClosesThemEvenDuringFilePicker() {
        let popover = TrackingPopover()
        let delegate = AppDelegate(popover: popover)
        let picker = FocusChangingPicker()
        picker.duringPresentation = {
            XCTAssertTrue(SystemPanelPresentation.shared.isPresenting)
            delegate.dismissForOutsideClick(window: picker)
            XCTAssertEqual(popover.closeRequests, 1)
        }
        FileShortcuts().add(panel: picker)
    }

    @MainActor func testFilePickerFocusTransferDoesNotClosePopoverAndCancelRestoresDismissal() {
        let popover = TrackingPopover()
        let delegate = AppDelegate(popover: popover)
        delegate.installDismissalMonitors()
        defer { delegate.popoverDidClose(Notification(name: NSPopover.didCloseNotification)) }
        let picker = FocusChangingPicker()
        picker.duringPresentation = { XCTAssertEqual(popover.closeRequests, 0, "Picker interaction must preserve the Files page") }
        FileShortcuts().add(panel: picker)
        XCTAssertEqual(popover.closeRequests, 0)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertEqual(popover.closeRequests, 1, "Normal outside dismissal must resume after cancellation")
    }

    @MainActor func testPermissionAlertActivationKeepsMenusOpenUntilAnswered() {
        let popover = TrackingPopover()
        let delegate = AppDelegate(popover: popover)
        delegate.installDismissalMonitors()
        defer { delegate.popoverDidClose(Notification(name: NSPopover.didCloseNotification)) }
        delegate.isPermissionAlertShowing = { true }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertEqual(popover.closeRequests, 0, "A system permission alert taking key focus must not dismiss the menus")
        delegate.isPermissionAlertShowing = { false }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertEqual(popover.closeRequests, 1, "Normal outside dismissal resumes once the alert is answered")
    }

    @MainActor func testLocationConsentClickInOwnAlertWindowKeepsMenusOpen() {
        let popover = TrackingPopover()
        let delegate = AppDelegate(popover: popover)
        delegate.isLocationPermissionInFlight = { true }
        let alertWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        delegate.handleLocalMouseDown(window: alertWindow)
        XCTAssertEqual(popover.closeRequests, 0, "Answering the in-process CoreLocation consent alert must not dismiss the menus")
        delegate.isLocationPermissionInFlight = { false }
        delegate.handleLocalMouseDown(window: alertWindow)
        XCTAssertEqual(popover.closeRequests, 1, "Normal own-window dismissal resumes once the alert is answered")
    }

    @MainActor func testPermissionAlertPredicateMatchesFrontmostBundleAndWindowOwners() {
        XCTAssertTrue(AppDelegate.permissionAlertShowing(
            frontmostBundleID: AppDelegate.permissionAlertBundleID, onScreenOwnerNames: []))
        XCTAssertTrue(AppDelegate.permissionAlertShowing(
            frontmostBundleID: "com.apple.Safari", onScreenOwnerNames: ["Finder", "userNotificationCenter"]))
        XCTAssertFalse(AppDelegate.permissionAlertShowing(
            frontmostBundleID: "com.apple.Safari", onScreenOwnerNames: ["Finder", "NotificationCenter"]))
        XCTAssertFalse(AppDelegate.permissionAlertShowing(frontmostBundleID: nil, onScreenOwnerNames: []))
    }
}
