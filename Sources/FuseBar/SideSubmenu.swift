import AppKit
import SwiftUI

@MainActor
final class SideSubmenu: NSObject, ObservableObject, NSPopoverDelegate {
    static let shared = SideSubmenu()
    @Published private(set) var selection: String?
    private let popover: NSPopover
    private var anchors: [String: WeakAnchor] = [:]
    private weak var parentWindow: NSWindow?
    private var pointerWindow: NSWindow?

    private final class WeakAnchor {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }

    init(popover: NSPopover? = nil) {
        self.popover = popover ?? NSPopover()
        super.init()
        self.popover.behavior = .applicationDefined
        self.popover.animates = false
        self.popover.delegate = self
    }

    var isShown: Bool { popover.isShown }
    func contains(_ window: NSWindow?) -> Bool {
        guard isShown, let window else { return false }
        return window === popover.contentViewController?.view.window
    }
    /// True when a screen point lies inside the submenu's popover window.
    func frameContains(_ point: NSPoint) -> Bool {
        guard isShown, let window = popover.contentViewController?.view.window else { return false }
        return window.frame.contains(point)
    }
    func register(_ view: NSView, for id: String) { anchors[id] = WeakAnchor(view) }

    func toggle(_ id: String, content: AnyView) {
        if selection == id, isShown { close(restoreParent: true); return }
        guard let anchor = anchors[id]?.view, let window = anchor.window else { return }
        close()
        parentWindow = window
        selection = id
        popover.contentViewController = NSHostingController(rootView: content)
        // AppKit constrains the popover to the visible screen and flips edges when necessary.
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
        if popover.isShown {
            popover.contentViewController?.view.window?.makeKey()
            showAnchorPointer(for: anchor)
        } else { selection = nil }
    }

    func close(restoreParent: Bool = false) {
        let parent = parentWindow
        hideAnchorPointer()
        popover.performClose(nil)
        selection = nil
        parentWindow = nil
        if restoreParent, parent?.isVisible == true { parent?.makeKey() }
    }

    func popoverDidClose(_ notification: Notification) { hideAnchorPointer(); selection = nil }

    /// A small material triangle bridging the submenu to its parent row. The two
    /// rounded panels meet flush; without it the corner notch reads as an odd
    /// lens instead of a deliberate anchor.
    private func showAnchorPointer(for anchor: NSView) {
        guard let panel = popover.contentViewController?.view.window,
              let anchorWindow = anchor.window else { return }
        let rowScreen = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let panelScreen = panel.frame
        // The popover sits to the right of the panel (tip points left) or, after
        // a screen-edge flip, to the left (tip points right).
        let pointsLeft = panelScreen.minX >= rowScreen.maxX - 1
        let size = NSSize(width: 9, height: 13)
        var centerY = rowScreen.midY
        centerY = min(max(centerY, panelScreen.minY + size.height), panelScreen.maxY - size.height)
        let originX = pointsLeft ? panelScreen.minX - size.width + 3 : panelScreen.maxX - 3
        let window = NSWindow(contentRect: NSRect(x: originX, y: centerY - size.height / 2, width: size.width, height: size.height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = panel.level
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]
        window.contentView = AnchorPointerView(pointsLeft: pointsLeft)
        pointerWindow = window
        window.orderFrontRegardless()
    }

    private func hideAnchorPointer() {
        pointerWindow?.orderOut(nil)
        pointerWindow = nil
    }
}

/// Material-filled triangle drawn in its own tiny borderless window, masked to shape.
final class AnchorPointerView: NSView {
    private let pointsLeft: Bool
    private let effect = NSVisualEffectView()

    init(pointsLeft: Bool) {
        self.pointsLeft = pointsLeft
        super.init(frame: .zero)
        wantsLayer = true
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        addSubview(effect)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        effect.frame = bounds
        let path = CGMutablePath()
        let b = bounds
        if pointsLeft {
            path.move(to: CGPoint(x: b.minX, y: b.midY))
            path.addLine(to: CGPoint(x: b.maxX, y: b.maxY))
            path.addLine(to: CGPoint(x: b.maxX, y: b.minY))
        } else {
            path.move(to: CGPoint(x: b.maxX, y: b.midY))
            path.addLine(to: CGPoint(x: b.minX, y: b.maxY))
            path.addLine(to: CGPoint(x: b.minX, y: b.minY))
        }
        path.closeSubpath()
        let mask = CAShapeLayer()
        mask.path = path
        layer?.mask = mask
    }
}

private final class SubmenuAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct SideSubmenuAnchor: NSViewRepresentable {
    let id: String
    func makeNSView(context: Context) -> NSView {
        let view = SubmenuAnchorView()
        SideSubmenu.shared.register(view, for: id)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        SideSubmenu.shared.register(view, for: id)
    }
}
