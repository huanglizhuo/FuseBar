import AppKit
import SwiftUI
import XCTest
@testable import FuseBar

@MainActor private final class SubmenuPopover: NSPopover {
    var simulatedShown = false
    var edge: NSRectEdge?
    var closes = 0
    let childWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                               styleMask: .borderless, backing: .buffered, defer: false)
    override var isShown: Bool { simulatedShown }
    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        edge = preferredEdge
        childWindow.contentViewController = contentViewController
        simulatedShown = true
    }
    override func performClose(_ sender: Any?) {
        simulatedShown = false
        closes += 1
        delegate?.popoverDidClose?(Notification(name: NSPopover.didCloseNotification, object: self))
    }
}

final class SideSubmenuTests: XCTestCase {
    @MainActor private func controls(in element: AnyObject) -> [AnyObject] {
        let children = element.accessibilityChildren?() ?? []
        return [element] + children.flatMap { controls(in: $0 as AnyObject) }
    }

    @MainActor func testWiFiConfirmationCancelEscapeReopenAndRetryStayInsideSubmenu() throws {
        // Enable the in-process SwiftUI accessibility tree; no external AX permission is needed.
        let accessibility = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousAccessibility = NSApp.accessibilityAttributeValue(accessibility)
        NSApp.accessibilitySetValue(true, forAttribute: accessibility)
        defer { NSApp.accessibilitySetValue(previousAccessibility ?? false, forAttribute: accessibility) }
        let suite = "FuseBarTests.WiFiConfirmation.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = SubmenuPopover()
        root.simulatedShown = true
        let child = SubmenuPopover()
        let submenu = SideSubmenu(popover: child)
        let delegate = AppDelegate(popover: root, sideSubmenu: submenu)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 500))
        root.childWindow.contentView = anchor
        submenu.register(anchor, for: "wifi")
        let writer = WiFiPowerWriter()
        let controller = WiFiPanelStore(preview: true, writePower: { try writer.write($0) })
        let store = StatusStore(defaults: defaults, demo: true)
        func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        func open() {
            submenu.toggle("wifi", content: AnyView(WiFiPanel(store: store, preview: true, isSubmenu: true,
                                                            controller: controller).frame(width: 320)))
            child.childWindow.orderFront(nil)
            settle()
        }
        func find(_ label: String) -> AnyObject? {
            guard let content = child.contentViewController?.view else { return nil }
            return controls(in: content).first { $0.accessibilityLabel?() == label && $0.accessibilityRole?() != .staticText }
        }
        func press(_ label: String) throws {
            let button = try XCTUnwrap(find(label))
            let window = try XCTUnwrap(button.accessibilityWindow?() as? NSWindow)
            XCTAssertTrue(window === child.childWindow, "Confirmation must use the existing submenu window")
            delegate.handleLocalMouseDown(window: window)
            XCTAssertTrue(child.isShown)
            XCTAssertTrue(root.isShown)
            XCTAssertTrue(button.accessibilityPerformPress?() == true)
            settle()
        }
        func awaitPowerWrite() {
            let deadline = Date().addingTimeInterval(2)
            while controller.busy && Date() < deadline { settle() }
            XCTAssertFalse(controller.busy)
        }
        open()
        defer { submenu.close(); child.childWindow.orderOut(nil) }
        try press("Wi-Fi")
        XCTAssertNotNil(find(L("关闭 Wi-Fi")))
        XCTAssertTrue(writer.requests.isEmpty, "Requesting confirmation must not change Wi-Fi")
        try press(L("取消"))
        XCTAssertNil(find(L("关闭 Wi-Fi")))
        XCTAssertTrue(writer.requests.isEmpty)

        try press("Wi-Fi")
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: child.childWindow.windowNumber, context: nil,
                                                   characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                                   isARepeat: false, keyCode: 53))
        delegate.dismissInnermostPanel(event: escape)
        settle()
        XCTAssertNil(find(L("关闭 Wi-Fi")), "First Escape cancels confirmation")
        XCTAssertTrue(child.isShown)
        XCTAssertTrue(writer.requests.isEmpty)
        delegate.dismissInnermostPanel(event: escape)
        XCTAssertFalse(child.isShown, "Second Escape closes the submenu")
        XCTAssertTrue(root.isShown)

        open()
        try press("Wi-Fi")
        delegate.handleLocalMouseDown(window: nil)
        XCTAssertFalse(child.isShown)
        XCTAssertFalse(root.isShown)
        root.simulatedShown = true
        open()
        XCTAssertNil(find(L("关闭 Wi-Fi")), "Reopening must not resurrect confirmation")
        XCTAssertTrue(writer.requests.isEmpty)

        try press("Wi-Fi")
        let confirm = try XCTUnwrap(find(L("关闭 Wi-Fi")))
        delegate.handleLocalMouseDown(window: confirm.accessibilityWindow?() as? NSWindow)
        XCTAssertTrue(child.isShown)
        XCTAssertTrue(confirm.accessibilityPerformPress?() == true)
        _ = confirm.accessibilityPerformPress?() // A queued second press must not submit another write.
        awaitPowerWrite()
        settle()
        XCTAssertEqual(writer.requests, [false])
        XCTAssertTrue(controller.failed)
        XCTAssertFalse(controller.message.isEmpty)
        XCTAssertNil(find(L("关闭 Wi-Fi")))
        try press("Wi-Fi")
        try press(L("关闭 Wi-Fi"))
        awaitPowerWrite()
        XCTAssertEqual(writer.requests, [false, false])
        XCTAssertFalse(controller.failed)
        XCTAssertTrue(controller.message.isEmpty)
        XCTAssertTrue(child.isShown)
    }

    @MainActor func testEscapeClosesChildBeforeParentAndParentClosureClosesChild() {
        let root = SubmenuPopover()
        root.simulatedShown = true
        let child = SubmenuPopover()
        child.simulatedShown = true
        let submenu = SideSubmenu(popover: child)
        let delegate = AppDelegate(popover: root, sideSubmenu: submenu)
        delegate.dismissInnermostPanel()
        XCTAssertFalse(child.simulatedShown)
        XCTAssertTrue(root.simulatedShown)
        XCTAssertEqual(root.closes, 0)
        delegate.dismissInnermostPanel()
        XCTAssertFalse(root.simulatedShown)
        child.simulatedShown = true
        delegate.popoverDidClose(Notification(name: NSPopover.didCloseNotification))
        XCTAssertFalse(child.simulatedShown)
    }

    @MainActor func testNativePopoverFitsScreenAndFlipsAtRightEdge() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let visible = screen.visibleFrame
        guard visible.width > 700 else { throw XCTSkip("Screen too narrow for two 300-point panels") }
        let parent = NSWindow(contentRect: NSRect(x: visible.minX + 20, y: visible.midY, width: 320, height: 160),
                              styleMask: .borderless, backing: .buffered, defer: false)
        parent.alphaValue = 0
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 160))
        parent.contentView = anchor
        parent.orderFront(nil)
        let popover = NSPopover()
        let submenu = SideSubmenu(popover: popover)
        submenu.register(anchor, for: "test")
        defer { submenu.close(); parent.orderOut(nil) }
        for rightEdge in [false, true] {
            submenu.close()
            parent.setFrameOrigin(NSPoint(x: rightEdge ? visible.maxX - 340 : visible.minX + 20, y: visible.midY))
            submenu.toggle("test", content: AnyView(Text("Placement test").frame(width: 300, height: 120)))
            XCTAssertTrue(submenu.isShown)
            let child = try XCTUnwrap(popover.contentViewController?.view.window)
            XCTAssertGreaterThanOrEqual(child.frame.minX, visible.minX - 1)
            XCTAssertLessThanOrEqual(child.frame.maxX, visible.maxX + 1)
            if rightEdge { XCTAssertLessThan(child.frame.midX, parent.frame.midX) }
            else { XCTAssertGreaterThan(child.frame.midX, parent.frame.midX) }
        }
    }

    @MainActor func testOutsideClickClosesBothWhileInsideClicksKeepBothOpen() {
        let root = SubmenuPopover()
        root.contentViewController = NSViewController()
        root.childWindow.contentViewController = root.contentViewController
        root.simulatedShown = true
        let child = SubmenuPopover()
        child.contentViewController = NSViewController()
        child.childWindow.contentViewController = child.contentViewController
        child.simulatedShown = true
        let submenu = SideSubmenu(popover: child)
        let delegate = AppDelegate(popover: root, sideSubmenu: submenu)
        delegate.dismissForOutsideClick(window: root.childWindow)
        delegate.dismissForOutsideClick(window: child.childWindow)
        XCTAssertTrue(root.simulatedShown)
        XCTAssertTrue(child.simulatedShown)
        delegate.dismissForOutsideClick(window: nil)
        XCTAssertFalse(root.simulatedShown)
        XCTAssertFalse(child.simulatedShown)
        root.simulatedShown = true
        child.simulatedShown = true
        let otherWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        delegate.dismissForOutsideClick(window: otherWindow)
        XCTAssertFalse(root.simulatedShown)
        XCTAssertFalse(child.simulatedShown)
    }

    /// The activation click can leak into the global monitor even when it lands in
    /// our own popover; screen-point hits inside either panel are never dismissals.
    @MainActor func testOwnPanelHitsAreNotOutsideClicks() {
        let root = SubmenuPopover()
        root.contentViewController = NSViewController()
        root.childWindow.contentViewController = root.contentViewController
        root.simulatedShown = true
        let child = SubmenuPopover()
        child.contentViewController = NSViewController()
        child.childWindow.contentViewController = child.contentViewController
        child.simulatedShown = true
        let submenu = SideSubmenu(popover: child)
        let delegate = AppDelegate(popover: root, sideSubmenu: submenu)
        root.childWindow.setFrame(NSRect(x: 100, y: 100, width: 300, height: 200), display: false)
        XCTAssertTrue(delegate.pointFallsInsideOwnPanels(NSPoint(x: 250, y: 200)))
        child.childWindow.setFrame(NSRect(x: 500, y: 100, width: 300, height: 200), display: false)
        XCTAssertTrue(delegate.pointFallsInsideOwnPanels(NSPoint(x: 650, y: 200)))
        XCTAssertFalse(delegate.pointFallsInsideOwnPanels(NSPoint(x: 20, y: 20)))
        child.simulatedShown = false
        XCTAssertFalse(delegate.pointFallsInsideOwnPanels(NSPoint(x: 650, y: 200)))
    }

    @MainActor func testOwnedWindowSwitchingAndToggleClose() {
        let popover = SubmenuPopover()
        let submenu = SideSubmenu(popover: popover)
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 500),
                              styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 60))
        parent.contentView = anchor
        submenu.register(anchor, for: "wifi")
        submenu.register(anchor, for: "sound")
        submenu.toggle("wifi", content: AnyView(Text("Wi-Fi")))
        XCTAssertEqual(submenu.selection, "wifi")
        XCTAssertEqual(popover.edge, .maxX)
        XCTAssertTrue(submenu.contains(popover.childWindow))
        XCTAssertFalse(submenu.contains(parent))
        XCTAssertFalse(submenu.contains(nil))
        submenu.toggle("sound", content: AnyView(Text("Sound")))
        XCTAssertEqual(submenu.selection, "sound")
        XCTAssertTrue(submenu.isShown)
        submenu.toggle("sound", content: AnyView(Text("Sound")))
        XCTAssertFalse(submenu.isShown)
        XCTAssertNil(submenu.selection)
        XCTAssertFalse(submenu.contains(popover.childWindow))
        submenu.toggle("missing", content: AnyView(EmptyView()))
        XCTAssertFalse(submenu.isShown)
    }
}

private final class WiFiPowerWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Bool] = []
    var requests: [Bool] { lock.withLock { values } }
    func write(_ enabled: Bool) throws -> Bool {
        let first = lock.withLock { values.append(enabled); return values.count == 1 }
        if first { throw NSError(domain: "FuseBarTests.WiFi", code: 1) }
        return true
    }
}
