import AppKit
import SwiftUI

@MainActor
final class SideSubmenu: NSObject, ObservableObject, NSPopoverDelegate {
    static let shared = SideSubmenu()
    @Published private(set) var selection: String?
    private let popover: NSPopover
    private var anchors: [String: WeakAnchor] = [:]
    private weak var parentWindow: NSWindow?

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
        if popover.isShown { popover.contentViewController?.view.window?.makeKey() }
        else { selection = nil }
    }

    func close(restoreParent: Bool = false) {
        let parent = parentWindow
        popover.performClose(nil)
        selection = nil
        parentWindow = nil
        if restoreParent, parent?.isVisible == true { parent?.makeKey() }
    }

    func popoverDidClose(_ notification: Notification) { selection = nil }
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
