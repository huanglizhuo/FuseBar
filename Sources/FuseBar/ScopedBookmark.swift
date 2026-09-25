import Foundation

/// Security-scoped bookmark helpers shared by file shortcuts, coding projects and
/// the application shelf. All user selections are read-only scopes.
enum ScopedBookmark {
    /// Creates a read-only security-scoped bookmark for a user-selected URL.
    static func readScope(for url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Resolves a security-scoped bookmark. The app shelf resolves without mounting;
    /// opening user entries keeps the default mounting behavior.
    static func resolve(_ data: Data, withoutMounting: Bool = false) throws -> (url: URL, stale: Bool) {
        var stale = false
        var options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
        if withoutMounting { options.insert(.withoutMounting) }
        let url = try URL(resolvingBookmarkData: data, options: options,
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        return (url, stale)
    }
}
