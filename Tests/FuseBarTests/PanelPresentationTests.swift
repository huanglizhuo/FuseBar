import AppKit
import SwiftUI
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

    @MainActor func testFirstRunGuideLeavesForFocusedSearchOnReturn() throws {
        let suite = "FuseBarTests.Onboarding.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let view = PopoverView(store: StatusStore(defaults: defaults, demo: true),
                               shelf: ApplicationShelf(defaults: defaults, readApplications: { [] }))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 800), styleMask: .titled, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(defaults.bool(forKey: "onboardingComplete"), "Seeing the guide once completes onboarding")
        XCTAssertFalse(window.firstResponder is NSTextView, "The first-run guide has no search field")
        let returnKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                        windowNumber: window.windowNumber, context: nil, characters: "\r",
                                                        charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertTrue(window.performKeyEquivalent(with: returnKey))
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(window.firstResponder is NSTextView, "Get started lands on home with search focused")
    }

    @MainActor func testSettingsWindowClosesOnEscapeAndCommandW() throws {
        let window = SettingsWindow()
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.cancelOperation(nil)
        XCTAssertFalse(window.isVisible)
        window.makeKeyAndOrderFront(nil)
        let commandW = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                                       windowNumber: window.windowNumber, context: nil, characters: "w",
                                                       charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13))
        XCTAssertTrue(window.performKeyEquivalent(with: commandW))
        XCTAssertFalse(window.isVisible)
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

    // MARK: - Search composition vs. first click

    /// Hosts the real panel in a plain window and lands on the home page with the
    /// search field focused (same Return-through-onboarding path as the guide
    /// test — the window never becomes key in the headless runner, so the
    /// SwiftUI focus pipeline is the only way the field editor materializes),
    /// then plants an input-method composition, mirroring a user typing pinyin.
    @MainActor private func windowWithComposingSearchField() throws -> (NSWindow, NSTextView) {
        let suite = "FuseBarTests.Composition.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 320, height: 800),
                              styleMask: .titled, backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = NSHostingView(rootView: PopoverView(
            store: StatusStore(defaults: defaults, demo: true),
            shelf: ApplicationShelf(defaults: defaults, readApplications: { [] })))
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let returnKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                        windowNumber: window.windowNumber, context: nil, characters: "\r",
                                                        charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertTrue(window.performKeyEquivalent(with: returnKey), "Return leaves the first-run guide for home")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let editor = try XCTUnwrap(window.firstResponder as? NSTextView, "Home lands on the auto-focused search field")
        editor.setMarkedText("ni", selectedRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        return (window, editor)
    }

    @MainActor func testClickOnPanelRowDuringCompositionDiscardsMarkedText() throws {
        let (window, editor) = try windowWithComposingSearchField()
        defer { window.orderOut(nil) }
        let click = NSPoint(x: window.frame.midX, y: window.frame.minY + 6)
        XCTAssertTrue(AppDelegate.discardActiveComposition(in: [window], clickLocation: click),
                      "A row click during composition must end the composition")
        XCTAssertFalse(editor.hasMarkedText(), "The row click must not be spent committing the composition")
        XCTAssertEqual(editor.string, "", "Discarded pinyin must not become the search query")
    }

    @MainActor func testCompositionWithoutOurWindowsStays() throws {
        let (window, editor) = try windowWithComposingSearchField()
        defer { window.orderOut(nil) }
        XCTAssertFalse(AppDelegate.discardActiveComposition(in: [], clickLocation: NSPoint(x: 10, y: 10)),
                       "No panel window, nothing to discard")
        XCTAssertTrue(editor.hasMarkedText())
    }

    @MainActor func testClickInsideSearchFieldKeepsComposition() throws {
        let (window, editor) = try windowWithComposingSearchField()
        defer { window.orderOut(nil) }
        let fieldFrame = window.convertToScreen(editor.convert(editor.bounds, to: nil))
        let kept = AppDelegate.discardActiveComposition(in: [window], clickLocation: NSPoint(x: fieldFrame.midX, y: fieldFrame.midY))
        XCTAssertFalse(kept)
        XCTAssertTrue(editor.hasMarkedText(), "Clicking back into the field edits the composition instead of ending it")
    }
}
