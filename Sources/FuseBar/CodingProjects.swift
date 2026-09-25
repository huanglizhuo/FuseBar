import AppKit
import SwiftUI

struct CodingProject: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var folder: Data?
    var folderName: String?
    var preview: String
    var repository: String

    static func webURL(_ text: String) -> URL? {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (preview.isEmpty || Self.webURL(preview) != nil) &&
            (repository.isEmpty || Self.webURL(repository) != nil)
    }
}

@MainActor
final class CodingProjects: ObservableObject {
    @Published private(set) var items: [CodingProject] = []
    @Published var selectedID: UUID? { didSet { defaults.set(selectedID?.uuidString, forKey: "selectedCodingProject") } }
    @Published var error: String?
    private let defaults: UserDefaults
    var current: CodingProject? { items.first { $0.id == selectedID } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "codingProjects") {
            do { items = try JSONDecoder().decode([CodingProject].self, from: data) }
            catch { self.error = L("项目配置无法读取，请重新添加。") }
        }
        let saved = defaults.string(forKey: "selectedCodingProject").flatMap(UUID.init(uuidString:))
        selectedID = items.contains { $0.id == saved } ? saved : items.first?.id
    }
    @discardableResult func save(_ project: CodingProject) -> Bool {
        guard project.valid else { error = L("请输入项目名和有效的 HTTP(S) 地址，不可包含账号密码。"); return false }
        var updated = items
        if let index = updated.firstIndex(where: { $0.id == project.id }) { updated[index] = project }
        else { updated.append(project) }
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: "codingProjects")
            items = updated; selectedID = project.id; error = nil
            return true
        } catch { self.error = L("无法保存项目。"); return false }
    }
    func remove(_ id: UUID) {
        let updated = items.filter { $0.id != id }
        guard let data = try? JSONEncoder().encode(updated) else { error = L("无法保存项目。"); return }
        defaults.set(data, forKey: "codingProjects")
        items = updated
        if selectedID == id { selectedID = items.first?.id }
        error = nil
    }
    func chooseFolder() -> (Data, String)? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.title = L("选择项目目录")
        guard SystemPanelPresentation.shared.run(panel) == .OK, let url = panel.url else { return nil }
        do {
            return (try ScopedBookmark.readScope(for: url), url.lastPathComponent)
        } catch { self.error = L("无法授权目录，请重新选择。"); return nil }
    }
    func openFolder(_ project: CodingProject) {
        guard let bookmark = project.folder else { return }
        do {
            let resolved = try ScopedBookmark.resolve(bookmark)
            let url = resolved.url
            guard url.startAccessingSecurityScopedResource() else { error = L("目录授权失效，请编辑项目并重新选择。"); return }
            // A stale scope is not silently used; the edit action gives a clear recovery path.
            guard !resolved.stale else { url.stopAccessingSecurityScopedResource(); error = L("目录授权失效，请编辑项目并重新选择。"); return }
            NSWorkspace.shared.open(url, configuration: .init()) { [weak self] _, failure in
                url.stopAccessingSecurityScopedResource()
                Task { @MainActor in self?.error = failure == nil ? nil : L("无法打开项目入口，请检查路径或默认应用。") }
            }
        } catch { self.error = L("目录授权失效，请编辑项目并重新选择。") }
    }
    func openWeb(_ text: String) {
        guard let url = CodingProject.webURL(text) else { error = L("请输入项目名和有效的 HTTP(S) 地址，不可包含账号密码。"); return }
        error = NSWorkspace.shared.open(url) ? nil : L("无法打开项目入口，请检查路径或默认应用。")
    }
}

struct ProjectEditorView: View {
    @ObservedObject var projects: CodingProjects
    @State private var draft = CodingProject(name: "", preview: "", repository: "")
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("项目工作台")).font(.headline)
                Spacer()
                Button(L("新建")) { draft = CodingProject(name: "", preview: "", repository: ""); projects.error = nil }
            }
            if !projects.items.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(projects.items) { project in
                            Button(project.name) { draft = project; projects.error = nil }
                        }
                    }
                }
            }
            TextField(L("项目名称"), text: $draft.name).accessibilityLabel(L("项目名称"))
            HStack {
                Button(L("选择项目目录")) {
                    if let (bookmark, name) = projects.chooseFolder() { draft.folder = bookmark; draft.folderName = name }
                }
                Text(draft.folderName ?? "—").font(.caption).lineLimit(1)
                if draft.folder != nil {
                    Button { draft.folder = nil; draft.folderName = nil } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(L("移除目录入口"))
                }
            }
            Text(L("预览")).font(.caption).foregroundStyle(.secondary)
            TextField(L("预览地址，例如 http://localhost:3000"), text: $draft.preview).accessibilityLabel(L("预览"))
            Text(L("仓库")).font(.caption).foregroundStyle(.secondary)
            TextField(L("仓库地址，例如 https://github.com/…"), text: $draft.repository).accessibilityLabel(L("仓库"))
            Text(L("仅打开你保存的入口。不会运行命令、启动服务器或恢复应用会话。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("保存")) {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.preview = draft.preview.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.repository = draft.repository.trimmingCharacters(in: .whitespacesAndNewlines)
                    projects.save(draft)
                }.disabled(!draft.valid)
                if projects.items.contains(where: { $0.id == draft.id }) {
                    Button(L("移除项目")) { projects.remove(draft.id); draft = CodingProject(name: "", preview: "", repository: "") }
                }
            }
            Text(L("移除项目只删除此处配置，不删除文件。"))
                .font(.caption2).foregroundStyle(.secondary)
            if let error = projects.error { Text(error).font(.caption).foregroundStyle(.red) }
        }.textFieldStyle(.roundedBorder).padding(18)
        .onAppear { if let current = projects.current { draft = current } }
    }
}
