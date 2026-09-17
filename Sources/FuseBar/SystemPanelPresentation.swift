import AppKit

/// A system picker may run in another process. Track its entire presentation,
/// rather than relying on NSApp.modalWindow to recognize its windows/events.
@MainActor
final class SystemPanelPresentation {
    static let shared = SystemPanelPresentation()
    private var depth = 0
    var isPresenting: Bool { depth > 0 }

    func run(_ panel: NSOpenPanel) -> NSApplication.ModalResponse {
        depth += 1
        defer { depth -= 1 }
        return panel.runModal()
    }
}
