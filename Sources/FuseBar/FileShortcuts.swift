import AppKit
import SwiftUI

struct FileShortcut: Codable, Identifiable {
    let id: UUID
    let name: String
    var bookmark: Data
}

@MainActor
final class FileShortcuts: ObservableObject {
    @Published private(set) var items: [FileShortcut]
    @Published var error: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = defaults.data(forKey: "fileShortcuts").flatMap { try? JSONDecoder().decode([FileShortcut].self, from: $0) } ?? []
    }

    func reload() {
        items = defaults.data(forKey: "fileShortcuts").flatMap { try? JSONDecoder().decode([FileShortcut].self, from: $0) } ?? []
    }

    func add(panel: NSOpenPanel = NSOpenPanel()) {
        panel.title = L("添加文件或文件夹到 FuseBar")
        panel.prompt = L("添加")
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        guard SystemPanelPresentation.shared.run(panel) == .OK else { return }
        do {
            var additions: [FileShortcut] = []
            for url in panel.urls {
                let data = try ScopedBookmark.readScope(for: url)
                additions.append(FileShortcut(id: UUID(), name: url.lastPathComponent, bookmark: data))
            }
            let updated = items + additions
            defaults.set(try JSONEncoder().encode(updated), forKey: "fileShortcuts")
            items = updated
            error = nil
        } catch { self.error = L("无法保存快捷入口，请重新选择项目。") }
    }

    func remove(_ item: FileShortcut) {
        items.removeAll { $0.id == item.id }
        do { try save() } catch { self.error = L("无法保存快捷入口。") }
    }

    func open(_ item: FileShortcut) {
        do {
            let resolved = try ScopedBookmark.resolve(item.bookmark)
            let url = resolved.url
            guard url.startAccessingSecurityScopedResource() else {
                error = L("访问授权已失效，请移除此入口并重新添加。")
                return
            }
            if resolved.stale {
                do {
                    let bookmark = try ScopedBookmark.readScope(for: url)
                    if let index = items.firstIndex(where: { $0.id == item.id }) { items[index].bookmark = bookmark }
                    try save()
                } catch {
                    url.stopAccessingSecurityScopedResource()
                    self.error = L("无法更新访问授权，请重新添加此项目。")
                    return
                }
            }
            NSWorkspace.shared.open(url, configuration: .init()) { [weak self] _, error in
                url.stopAccessingSecurityScopedResource()
                Task { @MainActor in
                    self?.error = error == nil ? nil : L("无法打开项目，它可能已被移动、删除或无法访问。")
                }
            }
        } catch { self.error = L("快捷入口已失效，请移除并重新添加。") }
    }

    private func save() throws { defaults.set(try JSONEncoder().encode(items), forKey: "fileShortcuts") }
}

struct FileShortcutsView: View {
    @StateObject private var shortcuts = FileShortcuts()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("文件与文件夹")).font(.headline)
                Spacer()
                Button(L("添加…")) { shortcuts.add() }
            }
            Text(L("选择 Downloads、工作文件夹或常用文件，保存在本机。"))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 10) {
                    if shortcuts.items.isEmpty {
                        Text(L("还没有快捷入口，点击“添加”选择项目。"))
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical)
                    }
                    ForEach(shortcuts.items) { item in
                        HStack {
                            Button { shortcuts.open(item) } label: {
                                Label(item.name, systemImage: "doc.on.doc").lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Button { shortcuts.remove(item) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).accessibilityLabel(L("移除快捷入口 %@", item.name))
                        }.padding(.vertical, 6)
                    }
                }
            }.frame(height: 280)
            if let error = shortcuts.error { Text(error).font(.caption).foregroundStyle(.red) }
            Text(L("移除快捷入口不会删除文件。文件内容不会上传。"))
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(18)
    }
}
