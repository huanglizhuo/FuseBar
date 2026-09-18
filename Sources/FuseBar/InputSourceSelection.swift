import Foundation

/// Focus restoration is best effort; it must not prevent a user-requested global input-source change.
@MainActor enum InputSourceSelection {
    static func perform(restoreFocus: () -> Void, select: () -> Bool) async -> Bool? {
        restoreFocus()
        // Allow AppKit's activation handoff to settle without making it a prerequisite.
        do { try await Task.sleep(nanoseconds: 100_000_000) }
        catch { return nil }
        guard !Task.isCancelled else { return nil }
        return select()
    }
}
