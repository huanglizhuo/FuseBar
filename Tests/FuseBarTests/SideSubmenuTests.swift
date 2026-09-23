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
