import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var store: StatusStore
    @ObservedObject private var inputSources: InputSourceStore
    private let onSelectInputSource: ((String) -> Void)?
    @StateObject private var shelf: ApplicationShelf
    @AppStorage("codingLayout") private var codingLayout = false
    @AppStorage("includeFavoriteApps") private var includeFavoriteApps = true
    @StateObject private var projects: CodingProjects
    @FocusState private var searchFocused: Bool
    @State private var searchIndex = 0
    @ObservedObject private var submenu = SideSubmenu.shared
    @StateObject private var files: FileShortcuts
    @State private var hoveredApp: String?
    @FocusState private var focusedStatus: Page?
    @FocusState private var focusedSource: String?
    private let focusSearch: Bool
    @State private var appQuery = ""
    @State private var runningOnly = false
    @State private var page: Page = .status
    @State private var editingVolume = false
    @State private var volume = 0.0
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    private let preview: Bool
    private let isSubmenu: Bool
    private let onOpenApplication: ((URL) -> Void)?
    private let onQuickAction: ((QuickAction) -> Void)?
    enum Page: Hashable { case battery, status, settings, guide, applications, sound, wifi, bluetooth, files, system, projects, inputSources }

    init(store: StatusStore, initialPage: Page = .status, preview: Bool = false, initialQuery: String = "", isSubmenu: Bool = false, focusSearch: Bool = false, onSelectInputSource: ((String) -> Void)? = nil, onQuickAction: ((QuickAction) -> Void)? = nil, onOpenApplication: ((URL) -> Void)? = nil, shelf: ApplicationShelf? = nil) {
        _shelf = StateObject(wrappedValue: shelf ?? ApplicationShelf.shared)
        _projects = StateObject(wrappedValue: CodingProjects(defaults: store.defaults))
        _files = StateObject(wrappedValue: FileShortcuts(defaults: store.defaults))
        self.focusSearch = focusSearch
        self.onSelectInputSource = onSelectInputSource
        let sources = preview ? InputSourceStore(defaults: store.defaults) : InputSourceStore.shared
        if preview { sources.refresh() }
        _inputSources = ObservedObject(wrappedValue: sources)
        _codingLayout = AppStorage(wrappedValue: false, "codingLayout", store: store.defaults)
        _includeFavoriteApps = AppStorage(wrappedValue: true, "includeFavoriteApps", store: store.defaults)
        self.store = store
        self.preview = preview
        self.isSubmenu = isSubmenu
        self.onQuickAction = onQuickAction
        self.onOpenApplication = onOpenApplication
        _page = State(initialValue: initialPage)
        _appQuery = State(initialValue: initialQuery)
    }

    var body: some View {
        Group {
            if isSubmenu { submenuContent }
            else { mainContent }
        }
        // The system focus halo paints wide horizontal bands above and below any
        // focused menu row; MenuButtonStyle already draws the selection outline.
        .focusEffectDisabled()
    }

    private func openSubmenu(_ destination: Page, anchor: String? = nil) {
        SideSubmenu.shared.toggle(anchor ?? String(describing: destination), content: AnyView(
            PopoverView(store: store, initialPage: destination, preview: preview, isSubmenu: true,
                        onSelectInputSource: onSelectInputSource, onQuickAction: onQuickAction,
                        onOpenApplication: onOpenApplication, shelf: shelf)))
    }

    private var submenuTitle: String {
        switch page {
        case .battery: return L("电池")
        case .wifi: return "Wi-Fi"
        case .sound: return L("声音")
        case .bluetooth: return L("蓝牙")
        case .inputSources: return L("输入源")
        default: return "FuseBar"
        }
    }

    private var submenuContent: some View {
        VStack(spacing: 0) {
            if ![.wifi, .sound, .bluetooth].contains(page) {
                HStack {
                    Text(submenuTitle).font(.headline)
                    Spacer()
                    Button { SideSubmenu.shared.close(restoreParent: true) } label: {
                        Image(systemName: "xmark").frame(width: 20, height: 20)
                    }.buttonStyle(.plain).help(L("关闭子菜单")).accessibilityLabel(L("关闭子菜单"))
                }.padding(16)
                Divider()
            }
            Group {
                switch page {
                case .battery:
                    VStack(alignment: .leading, spacing: 12) {
                        Label(store.snapshot.battery.detail, systemImage: StatusSymbols.battery(store.snapshot.battery))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(L("打开电池系统设置")) { SettingsDestination.battery.open() }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                case .wifi: WiFiPanel(store: store, preview: preview, isSubmenu: isSubmenu)
                case .sound: soundOutputs
                case .bluetooth: BluetoothPanel(store: store, preview: preview, isSubmenu: isSubmenu)
                case .inputSources: inputSourceList
                default: EmptyView()
                }
            }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).padding(12)
            }
        }.frame(width: 300)
            .onKeyPress(.leftArrow) {
                guard page != .wifi && page != .sound else { return .ignored }
                SideSubmenu.shared.close(restoreParent: true); return .handled
            }
            .background(.regularMaterial).environment(\.locale, L10n.locale)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if page != .status {
                HStack {
                    Button { page = .status } label: {
                        Label(L("返回"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("[", modifiers: .command)
                    .accessibilityLabel(L("返回首页"))
                    Spacer()
                }.font(.system(size: 12)).padding(.horizontal, 18).padding(.top, 12)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    OrbView(snapshot: store.snapshot, preferences: store.preferences, batteryRingTint: true).frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text("FuseBar").font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 4)
                    Button { page = .guide } label: {
                        Image(systemName: "questionmark.circle").frame(width: 24, height: 24)
                    }.buttonStyle(.borderless).help(L("图标说明与使用引导"))
                        .accessibilityLabel(L("图标说明与使用引导"))
                }
            }.padding(.horizontal, 18).padding(.vertical, 10)
            Divider()
            if page == .settings { ScrollView { settings }.frame(height: 420) }
            else if page == .guide || (!preview && !onboardingComplete) { ScrollView { guide }.frame(height: 420) }
            else if page == .applications { applications }
            else if page == .battery {
                VStack(alignment: .leading, spacing: 12) {
                    Label(store.snapshot.battery.detail, systemImage: StatusSymbols.battery(store.snapshot.battery))
                    Button(L("打开电池系统设置")) { SettingsDestination.battery.open() }
                }.padding(18)
            }
            else if page == .sound { soundOutputs }
            else if page == .wifi { WiFiPanel(store: store, preview: preview, isSubmenu: isSubmenu) }
            else if page == .bluetooth { BluetoothPanel(store: store, preview: preview, isSubmenu: isSubmenu) }
            else if page == .files { FileShortcutsView() }
            else if page == .system { SystemControlsView(store: store) }
            else if page == .projects { ProjectEditorView(projects: projects) }
            else if page == .inputSources { inputSourceList }
            else {
                VStack(spacing: 0) {
                    runningApplications
                    searchField
                    if showingSearchResults { searchResults }
                    if appQuery.isEmpty {
                        if codingLayout { codingHome }
                        else { status }
                    }
                }
            }
            if let error = store.errorMessage {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                    Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark.circle.fill").font(.caption) }
                        .buttonStyle(.plain).accessibilityLabel(L("关闭错误提示"))
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            Divider()
            ZStack {
                HStack {
                    Button { page = .settings; store.refreshLoginStatus() } label: {
                        Image(systemName: "gearshape").frame(width: 28, height: 28)
                    }.keyboardShortcut(",", modifiers: .command).disabled(page == .settings)
                        .help(L("设置…")).accessibilityLabel(L("设置…"))
                    Spacer()
                    Button { NSApplication.shared.terminate(nil) } label: {
                        Image(systemName: "power").frame(width: 28, height: 28)
                    }.keyboardShortcut("q").help(L("退出")).accessibilityLabel(L("退出"))
                }
                footerActions
            }.buttonStyle(MenuButtonStyle()).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary).padding(.horizontal, 18).padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .environment(\.locale, L10n.locale)
        .onAppear {
            volume = Double(store.snapshot.sound.volume ?? 0)
            store.refresh()
            if !preview { shelf.refresh(); shelf.discoverApplications() }
            if !preview || focusSearch { DispatchQueue.main.async { searchFocused = true } }
        }
        .onChange(of: page) { _, _ in SideSubmenu.shared.close(); appQuery = ""; searchFocused = false; files.reload() }
        .onChange(of: files.error) { _, error in if let error { store.errorMessage = error } }
        .onKeyPress(.leftArrow) {
            guard page != .status && page != .wifi && page != .sound else { return .ignored }
            page = .status
            return .handled
        }
        .onChange(of: codingLayout) { _, _ in SideSubmenu.shared.close() }
        .onChange(of: appQuery) { _, _ in SideSubmenu.shared.close() }
        .onChange(of: store.snapshot.sound.volume) { _, value in
            if !editingVolume { volume = Double(value ?? 0) }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 6) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Button { onQuickAction?(action) } label: {
                    Image(systemName: action.symbol).frame(width: 28, height: 28)
                }.help(action.title).accessibilityLabel(action.title)
                    .disabled(!preview && onQuickAction == nil)
            }
            Button { page = .files } label: {
                Image(systemName: "folder").frame(width: 28, height: 28)
            }.help(L("文件夹")).accessibilityLabel(L("文件夹"))

        }.buttonStyle(MenuButtonStyle()).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
    }

    private var inputSourcePicker: some View {
        Button { openSubmenu(.inputSources) } label: {
            HStack(spacing: 10) {
                Group {
                    if let current = inputSources.current { InputSourceGlyph(source: current).scaleEffect(0.9) }
                    else { Image(systemName: "keyboard") }
                }.frame(width: 20)
                Text(L("输入源")).font(.system(size: 12, weight: .medium))
                Spacer(minLength: 8)
                Text(inputSources.current?.name ?? L("输入源未知"))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                // Native macOS menus mark submenu rows with a filled triangle.
                Image(systemName: "arrowtriangle.right.fill").font(.system(size: 8)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 10).frame(height: 36).contentShape(Rectangle())
        }.buttonStyle(MenuButtonStyle(selected: submenu.selection == "inputSources"))
            .padding(.horizontal, 8).help(inputSources.current?.name ?? L("切换输入源"))
            .background(SideSubmenuAnchor(id: "inputSources"))
            .focusable().focused($focusedStatus, equals: .inputSources)
            .onKeyPress(.rightArrow) { openSubmenu(.inputSources); return .handled }
            .onKeyPress(.return) { openSubmenu(.inputSources); return .handled }
            .onKeyPress(.downArrow) { focusedStatus = .sound; return .handled }
            .onKeyPress(.upArrow) { focusedStatus = .bluetooth; return .handled }
    }

    private var inputSourceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isSubmenu { Text(L("输入源")).font(.headline) }
            ScrollView {
                VStack(spacing: 6) {
                    if inputSources.sources.isEmpty { Text(L("暂无可用输入源")).font(.caption).foregroundStyle(.secondary) }
                    ForEach(inputSources.sources) { source in
                        Button { onSelectInputSource?(source.id) } label: {
                            HStack(spacing: 10) {
                                InputSourceGlyph(source: source).frame(width: 20, height: 20)
                                Text(source.name).lineLimit(2)
                                Spacer()
                                if source.id == inputSources.currentID { Image(systemName: "checkmark") }
                            }.padding(10).frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(MenuButtonStyle(selected: source.id == inputSources.currentID))
                            .focusable().focused($focusedSource, equals: source.id)
                            .onKeyPress(.downArrow) { moveSourceFocus(source.id, offset: 1); return .handled }
                            .onKeyPress(.upArrow) { moveSourceFocus(source.id, offset: -1); return .handled }
                            .onKeyPress(.return) { onSelectInputSource?(source.id); return .handled }
                            .disabled(!preview && onSelectInputSource == nil)
                    }
                }
            }.frame(height: isSubmenu ? min(240, CGFloat(max(1, inputSources.sources.count)) * 46) : 240)
        }.padding(18).onAppear {
            if !preview {
                inputSources.refresh()
                DispatchQueue.main.async { focusedSource = inputSources.currentID ?? inputSources.sources.first?.id }
            }
        }
    }

    private func moveSourceFocus(_ id: String, offset: Int) {
        guard let index = inputSources.sources.firstIndex(where: { $0.id == id }), !inputSources.sources.isEmpty else { return }
        focusedSource = inputSources.sources[min(max(0, index + offset), inputSources.sources.count - 1)].id
    }

    private var searchEntries: [MenuSearchEntry] {
        let apps = shelf.searchable.compactMap { app -> MenuSearchEntry? in
            guard let url = app.url else { return nil }
            return MenuSearchEntry(id: "app:" + app.id, title: app.name, category: L("应用"), symbol: "app", destination: .application(url))
        }
        let shortcuts = files.items.map {
            MenuSearchEntry(id: "file:" + $0.id.uuidString, title: $0.name, category: L("文件与文件夹"), symbol: "doc.on.doc", destination: .file($0.id))
        }
        let actions: [(String, String, String)] = [
            ("battery", L("电池"), "battery.100percent"), ("wifi", "Wi-Fi", "wifi"),
            ("sound", L("声音输出"), "speaker.wave.2"), ("bluetooth", L("蓝牙"), StatusSymbols.bluetooth),
            ("inputSources", L("输入源"), "keyboard"), ("settings", L("设置…"), "gearshape"),
            ("files", L("文件与文件夹"), "folder"), ("projects", L("项目工作台"), "hammer"),
            ("applications", L("应用启动器"), "square.grid.3x3"), ("windows", L("所有窗口"), "rectangle.3.group"),
            ("system", L("系统"), "switch.2")]
        return apps + shortcuts + actions.map {
            MenuSearchEntry(id: "action:" + $0.0, title: $0.1, category: L("操作"), symbol: $0.2, destination: .action($0.0))
        }
    }
    private var searchMatches: [MenuSearchEntry] {
        MenuSearchModel.results(searchEntries, query: appQuery)
    }
    private var showingSearchResults: Bool {
        !appQuery.isEmpty
    }

    private var searchField: some View {
        TextField(L("搜索应用与操作…"), text: $appQuery)
            .textFieldStyle(.roundedBorder).focused($searchFocused)
            .accessibilityLabel(L("搜索应用与操作…"))
            .onChange(of: appQuery) { _, _ in searchIndex = 0 }
            .onSubmit { openSearchSelection() }
            .onKeyPress(.downArrow) {
                if searchMatches.isEmpty && appQuery.isEmpty { searchFocused = false; focusedStatus = .battery }
                else { searchIndex = min(searchIndex + 1, max(0, searchMatches.count - 1)) }
                return .handled
            }
            .onKeyPress(.upArrow) { searchIndex = max(0, searchIndex - 1); return .handled }
            .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private func openSearchSelection() {
        guard searchMatches.indices.contains(searchIndex) else { return }
        performSearchEntry(searchMatches[searchIndex])
    }

    private func performSearchEntry(_ entry: MenuSearchEntry) {
        switch entry.destination {
        case .application(let url): onOpenApplication?(url)
        case .file(let id):
            if let item = files.items.first(where: { $0.id == id }) { files.open(item) }
        case .action(let id):
            let statusPages: [String: Page] = ["battery": .battery, "wifi": .wifi, "sound": .sound, "bluetooth": .bluetooth, "inputSources": .inputSources]
            if let destination = statusPages[id] {
                openSubmenu(destination, anchor: "search:" + id)
                return
            }
            searchFocused = false
            appQuery = ""
            switch id {
            case "battery": page = .battery
            case "wifi": page = .wifi
            case "sound": page = .sound
            case "bluetooth": page = .bluetooth
            case "inputSources": page = .inputSources
            case "settings": page = .settings; store.refreshLoginStatus()
            case "files": page = .files
            case "projects": page = .projects
            case "system": page = .system
            case "applications": onQuickAction?(.applications)
            case "windows": onQuickAction?(.allWindows)
            default: break
            }
        }
    }

    private func searchResultButton(_ entry: MenuSearchEntry, index: Int, compact: Bool) -> some View {
        let anchor = "search:" + entry.id.replacingOccurrences(of: "action:", with: "")
        return Button { performSearchEntry(entry) } label: {
            HStack(spacing: compact ? 4 : 8) {
                Image(systemName: entry.symbol).frame(width: compact ? 14 : 20)
                Text(entry.title).lineLimit(1).truncationMode(.tail)
                if !compact {
                    Spacer(minLength: 4)
                    Text(entry.category).font(.caption2).foregroundStyle(.secondary)
                }
            }.font(.system(size: compact ? 11 : 12))
                .frame(maxWidth: .infinity, alignment: .leading).padding(compact ? 6 : 8).contentShape(Rectangle())
        }.buttonStyle(MenuButtonStyle(selected: index == searchIndex || submenu.selection == anchor))
            .background(SideSubmenuAnchor(id: anchor))
            .onKeyPress(.rightArrow) { performSearchEntry(entry); return .handled }
            .help(entry.title).accessibilityLabel(entry.title)
            .accessibilityValue(index == searchIndex ? L("已选择") : "")
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(searchMatches.enumerated()), id: \.element.id) { index, entry in
                            searchResultButton(entry, index: index, compact: false).id(index)
                        }
                        if searchMatches.isEmpty { Text(L("没有匹配结果")).font(.caption).padding(8) }
                    }
                }.frame(height: min(220, CGFloat(max(1, searchMatches.count)) * 36))
                .onChange(of: searchIndex) { _, index in reader.scrollTo(index) }
            }
            Text(L("↑↓ 选择 · Return 打开")).font(.caption2).foregroundStyle(.secondary)
        }.padding(.horizontal, 18).padding(.bottom, 10)
    }

    private var codingHome: some View {
        VStack(spacing: 0) {
            HStack {
                Button { openSubmenu(.battery) } label: {
                    Label(store.snapshot.battery.availability == .available ? "\(store.snapshot.battery.level)%" : "—", systemImage: StatusSymbols.battery(store.snapshot.battery))
                }.help(store.snapshot.battery.detail).background(SideSubmenuAnchor(id: "battery"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "battery", inset: 6))
                    .focusable().focused($focusedStatus, equals: .battery)
                    .onKeyPress(.rightArrow) { openSubmenu(.battery); return .handled }
                    .onKeyPress(.return) { openSubmenu(.battery); return .handled }
                    .onKeyPress(.downArrow) { moveStatusFocus(from: .battery, offset: 1); return .handled }
                    .onKeyPress(.upArrow) { moveStatusFocus(from: .battery, offset: -1); return .handled }
                Button { openSubmenu(.wifi) } label: { Image(systemName: StatusSymbols.wifi(store.snapshot.wifi)) }.help(store.snapshot.wifi.detail).background(SideSubmenuAnchor(id: "wifi"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "wifi", inset: 6))
                    .focusable().focused($focusedStatus, equals: .wifi)
                    .onKeyPress(.rightArrow) { openSubmenu(.wifi); return .handled }
                    .onKeyPress(.return) { openSubmenu(.wifi); return .handled }
                    .onKeyPress(.downArrow) { moveStatusFocus(from: .wifi, offset: 1); return .handled }
                    .onKeyPress(.upArrow) { moveStatusFocus(from: .wifi, offset: -1); return .handled }
                    .accessibilityLabel("Wi-Fi")
                Button { openSubmenu(.sound) } label: { Image(systemName: StatusSymbols.sound(store.snapshot.sound)) }.help(store.snapshot.sound.detail).background(SideSubmenuAnchor(id: "sound"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "sound", inset: 6))
                    .focusable().focused($focusedStatus, equals: .sound)
                    .onKeyPress(.rightArrow) { openSubmenu(.sound); return .handled }
                    .onKeyPress(.return) { openSubmenu(.sound); return .handled }
                    .onKeyPress(.downArrow) { moveStatusFocus(from: .sound, offset: 1); return .handled }
                    .onKeyPress(.upArrow) { moveStatusFocus(from: .sound, offset: -1); return .handled }
                    .accessibilityLabel(L("声音"))
                Button { openSubmenu(.bluetooth) } label: { Image(systemName: StatusSymbols.bluetooth) }.help(store.snapshot.bluetooth.detail).background(SideSubmenuAnchor(id: "bluetooth"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "bluetooth", inset: 6))
                    .focusable().focused($focusedStatus, equals: .bluetooth)
                    .onKeyPress(.rightArrow) { openSubmenu(.bluetooth); return .handled }
                    .onKeyPress(.return) { openSubmenu(.bluetooth); return .handled }
                    .onKeyPress(.downArrow) { moveStatusFocus(from: .bluetooth, offset: 1); return .handled }
                    .onKeyPress(.upArrow) { moveStatusFocus(from: .bluetooth, offset: -1); return .handled }
                    .accessibilityLabel(L("蓝牙"))
                Button { openSubmenu(.inputSources) } label: {
                    if let current = inputSources.current { InputSourceGlyph(source: current).frame(width: 14, height: 14) }
                    else { Image(systemName: "keyboard") }
                }.help(L("切换输入源")).accessibilityLabel(L("输入源")).background(SideSubmenuAnchor(id: "inputSources"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "inputSources", inset: 6))
                    .focusable().focused($focusedStatus, equals: .inputSources)
                    .onKeyPress(.rightArrow) { openSubmenu(.inputSources); return .handled }
                    .onKeyPress(.return) { openSubmenu(.inputSources); return .handled }
                    .onKeyPress(.downArrow) { moveStatusFocus(from: .inputSources, offset: 1); return .handled }
                    .onKeyPress(.upArrow) { moveStatusFocus(from: .inputSources, offset: -1); return .handled }
            }.controlSize(.small).foregroundStyle(.primary).padding(.horizontal, 18).padding(.bottom, 10)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("项目工作台")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { page = .projects } label: { Image(systemName: "pencil") }.buttonStyle(.plain)
                        .accessibilityLabel(L("项目工作台"))
                }
                if let current = projects.current {
                    Picker(L("当前项目"), selection: $projects.selectedID) {
                        ForEach(projects.items) { project in Text(project.name).tag(Optional(project.id)) }
                    }.labelsHidden()
                    HStack {
                        Button(L("目录")) { projects.openFolder(current) }.disabled(current.folder == nil)
                        Button(L("预览")) { projects.openWeb(current.preview) }.disabled(current.preview.isEmpty)
                        Button(L("仓库")) { projects.openWeb(current.repository) }.disabled(current.repository.isEmpty)
                    }.controlSize(.small)
                } else {
                    Button(L("添加项目入口")) { page = .projects }
                }
                if let error = projects.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(18)

        }
    }

    private var applications: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(runningOnly ? L("运行中的应用") : L("应用")).font(.headline)
                Spacer()
                Button(L("添加应用")) { store.errorMessage = shelf.addApplication() }
            }
            TextField(L("搜索常用和运行中的应用"), text: $appQuery)
                .textFieldStyle(.roundedBorder).accessibilityLabel(L("搜索应用"))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    let favorites = ApplicationShelfModel.visible(shelf.favorites.filter { !runningOnly || $0.running }, query: appQuery)
                    let running = ApplicationShelfModel.visible(shelf.running.filter { !shelf.isPinned($0) }, query: appQuery)
                    if favorites.isEmpty && running.isEmpty {
                        Text(appQuery.isEmpty ? L("没有可显示的应用。") : L("没有匹配的应用。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !favorites.isEmpty {
                        Text(L("常用应用")).font(.caption).foregroundStyle(.secondary)
                        ForEach(favorites) { app in applicationRow(app) }
                    }
                    if !running.isEmpty {
                        Text(L("运行中")).font(.caption).foregroundStyle(.secondary)
                        ForEach(running) { app in applicationRow(app) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 290)
            Text(L("点击打开，右键管理与排序。● 表示正在运行。"))
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(18)

    }

    private func applicationRow(_ app: ShelfApplication) -> some View {
        HStack(spacing: 8) {
            Button {
                if let url = app.url { onOpenApplication?(url) }
            } label: {
                HStack(spacing: 10) {
                    if let url = app.url {
                        ApplicationIcon(url: url).frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "app.dashed").frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).lineLimit(1)
                        if app.url == nil { Text(L("应用不可用，可取消固定")).font(.caption2).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 0)
                    if app.running { Image(systemName: "circle.fill").font(.system(size: 5)).accessibilityLabel(L("正在运行")) }
                }.contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle()).disabled(app.url == nil || onOpenApplication == nil)
            Button { shelf.togglePin(app) } label: {
                Image(systemName: shelf.isPinned(app) ? "pin.fill" : "pin")
            }.buttonStyle(.borderless)
                .accessibilityLabel("\(shelf.isPinned(app) ? L("取消固定") : L("固定")) \(app.name)")
        }.font(.system(size: 12)).padding(.vertical, 4)
        .contextMenu { applicationMenu(app) }
    }

    @ViewBuilder private func applicationMenu(_ app: ShelfApplication) -> some View {
            Button(shelf.isPinned(app) ? L("取消固定") : L("固定到 FuseBar")) { shelf.togglePin(app) }
            if shelf.isPinned(app) {
                Button(L("向前移动")) { shelf.move(app, offset: -1) }.disabled(!shelf.canMove(app, offset: -1))
                Button(L("向后移动")) { shelf.move(app, offset: 1) }.disabled(!shelf.canMove(app, offset: 1))
            }
            Divider()
            if app.running {
                Button(L("隐藏应用")) { store.errorMessage = shelf.setHidden(true, app: app) }
                Button(L("显示应用")) { store.errorMessage = shelf.setHidden(false, app: app) }
            }
            Button(L("在 Finder 中显示")) {
                if let url = app.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }.disabled(app.url == nil)
    }

    private var soundOutputs: some View {
        SoundPanel(store: store, preview: preview, isSubmenu: isSubmenu)
    }

    private var status: some View {
        VStack(spacing: 0) {
            statusRow(L("电池"), detail: store.snapshot.battery.availability == .available ? "\(store.snapshot.battery.level)%" + (store.snapshot.battery.charging ? " · " + L("正在充电") : store.snapshot.battery.low ? " · " + L("电量较低") : "") : store.snapshot.battery.detail, symbol: StatusSymbols.battery(store.snapshot.battery), destination: .battery)
            statusRow("Wi-Fi", detail: store.snapshot.wifi.connection == .connected ? (store.snapshot.wifi.name ?? store.snapshot.wifi.detail) : store.snapshot.wifi.detail, symbol: StatusSymbols.wifi(store.snapshot.wifi), destination: .wifi)
            if store.snapshot.wifi.shouldOfferNameAuthorization(store.networkNameAccess) {
                VStack(alignment: .leading, spacing: 5) {
                    Button(store.networkNameAccess == .blocked ? L("检查定位权限…") : L("显示网络名称…")) { store.requestNetworkName() }.font(.caption)
                    Text(L("需 macOS 定位授权；不会采集位置。"))
                        .font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 48).padding(.bottom, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                statusRow(L("蓝牙"), detail: store.snapshot.bluetooth.detail,
                          symbol: store.snapshot.bluetooth.state == .off ? "antenna.radiowaves.left.and.right.slash" : StatusSymbols.bluetooth,
                          destination: .bluetooth)
                if store.snapshot.bluetooth.state == .permissionRequired {
                    Button(L("允许读取蓝牙状态")) { store.enableBluetooth() }
                        .font(.caption).padding(.leading, 48).padding(.bottom, 12)
                } else if store.snapshot.bluetooth.state == .denied {
                    Button(L("打开蓝牙隐私设置")) { SettingsDestination.privacy.open() }
                        .font(.caption).padding(.leading, 48).padding(.bottom, 12)
                }
            }
            inputSourcePicker
            statusRow(L("声音"), detail: store.snapshot.sound.available ? store.snapshot.sound.deviceName : store.snapshot.sound.detail,
                      symbol: StatusSymbols.sound(store.snapshot.sound), destination: .sound)
            HStack(spacing: 8) {
                Button { store.setMuted(store.snapshot.sound.muted != true) } label: {
                    Image(systemName: store.snapshot.sound.muted == true ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 12)).frame(width: 24, height: 24)
                }.buttonStyle(MenuButtonStyle(selected: store.snapshot.sound.muted == true))
                    .disabled(store.audioBusy || !store.snapshot.sound.canSetMute)
                    .help(L("静音")).accessibilityLabel(L("静音"))
                    .accessibilityValue(store.snapshot.sound.muted == true ? L("已开启") : L("已关闭"))
                Slider(value: Binding(get: { volume }, set: { value in
                    volume = value
                    store.setVolume(value)
                }), in: 0...1, onEditingChanged: { editing in
                    editingVolume = editing
                    if !editing { store.setVolume(volume) }
                })
                .disabled(store.audioBusy || !store.snapshot.sound.canSetVolume)
                .accessibilityLabel(L("输出音量"))
                .accessibilityValue("\(Int(volume * 100))%")
                Text(store.snapshot.sound.volume == nil ? "—" : "\(Int((volume * 100).rounded()))%")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 32)
            }.padding(.horizontal, 20).padding(.bottom, 12)
            if store.snapshot.sound.muted == true {
                Text(L("系统静音已开启；调整音量不会自动取消静音。"))
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 10)
            }
        }
    }

    private var runningApplications: some View {
        let apps = ApplicationShelfModel.home(favorites: shelf.favorites, running: shelf.running, includeFavorites: includeFavoriteApps, recentIDs: shelf.recentIDs)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(includeFavoriteApps ? L("固定与运行应用") : L("运行中的应用")).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button { appQuery = ""; runningOnly = false; page = .applications } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain).accessibilityLabel(L("管理常用应用"))
            }
            if apps.isEmpty {
                Text(L("暂无运行中的应用")).font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 5) {
                    ForEach(Array(apps.prefix(apps.count > 12 ? 11 : 12))) { app in
                        Button { if let url = app.url { onOpenApplication?(url) } } label: {
                            Group {
                                if let url = app.url {
                                    ApplicationIcon(url: url).frame(width: 28, height: 28)
                                } else { Image(systemName: "app.dashed").frame(width: 28, height: 28) }
                            }.frame(width: 38, height: 34)
                                .background(shelf.frontmostID == app.id ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(alignment: .bottom) {
                                    if app.running { Circle().fill(.secondary).frame(width: 3, height: 3) }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if hoveredApp == app.id && shelf.isPinned(app) {
                                        Image(systemName: "pin.fill").font(.system(size: 8)).padding(2)
                                            .background(.regularMaterial, in: Circle()).accessibilityHidden(true)
                                    }
                                }.contentShape(Rectangle())
                        }.buttonStyle(MenuButtonStyle()).onHover { hoveredApp = $0 ? app.id : nil }.help(app.name).accessibilityLabel(L("打开 %@", app.name))
                            .accessibilityValue(shelf.frontmostID == app.id ? L("当前应用") : app.running ? L("正在运行") : L("固定"))
                            .contextMenu { applicationMenu(app) }
                            .disabled(app.url == nil || (!preview && onOpenApplication == nil))
                    }
                    if apps.count > 12 {
                        Button { appQuery = ""; runningOnly = !includeFavoriteApps; page = .applications } label: {
                            Image(systemName: "ellipsis").frame(width: 38, height: 34).contentShape(Rectangle())
                        }.buttonStyle(.plain).help(L("管理常用应用"))
                            .accessibilityLabel(L("管理常用应用"))
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 8)
    }

    private func statusRow(_ title: String, detail: String, symbol: String, destination: SettingsDestination) -> some View {
        Button {
            if destination == .sound { openSubmenu(.sound) }
            else if destination == .wifi { openSubmenu(.wifi) }
            else if destination == .bluetooth { openSubmenu(.bluetooth) }
            else if destination == .battery { openSubmenu(.battery) }
            else { destination.open() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol).font(.system(size: 14, weight: .medium)).frame(width: 20).foregroundStyle(.primary)
                Text(title).font(.system(size: 12, weight: .medium)).fixedSize()
                Spacer(minLength: 8)
                if statusWarning(destination) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(.orange)
                }
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Image(systemName: "arrowtriangle.right.fill").font(.system(size: 8)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 10).frame(height: 36).contentShape(Rectangle())
        }.buttonStyle(MenuButtonStyle(selected: submenu.selection == String(describing: destination)))
            .padding(.horizontal, 8).help(fullStatusDetail(destination))
            .accessibilityLabel(title + ": " + fullStatusDetail(destination))
            .background(SideSubmenuAnchor(id: String(describing: destination)))
            .focusable().focused($focusedStatus, equals: statusPage(destination))
            .onKeyPress(.rightArrow) { openSubmenu(statusPage(destination)); return .handled }
            .onKeyPress(.return) { openSubmenu(statusPage(destination)); return .handled }
            .onKeyPress(.downArrow) { moveStatusFocus(from: statusPage(destination), offset: 1); return .handled }
            .onKeyPress(.upArrow) { moveStatusFocus(from: statusPage(destination), offset: -1); return .handled }
    }

    private func fullStatusDetail(_ destination: SettingsDestination) -> String {
        switch destination {
        case .battery: return store.snapshot.battery.detail
        case .wifi: return store.snapshot.wifi.detail
        case .bluetooth: return store.snapshot.bluetooth.detail
        default: return store.snapshot.sound.detail
        }
    }

    private func statusPage(_ destination: SettingsDestination) -> Page {
        switch destination {
        case .battery: return .battery
        case .wifi: return .wifi
        case .bluetooth: return .bluetooth
        default: return .sound
        }
    }
    private func moveStatusFocus(from current: Page, offset: Int) {
        let order: [Page] = codingLayout ? [.battery, .wifi, .sound, .bluetooth, .inputSources] : [.battery, .wifi, .bluetooth, .inputSources, .sound]
        guard let index = order.firstIndex(of: current) else { return }
        let next = index + offset
        if next < 0 { searchFocused = true }
        else { focusedStatus = order[min(next, order.count - 1)] }
    }
    private func statusWarning(_ destination: SettingsDestination) -> Bool {
        switch destination {
        case .battery: return store.snapshot.battery.low
        case .wifi: return store.snapshot.wifi.connection == .disconnected
        default: return false
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("编码工作台")).font(.headline)
            Toggle(L("编码布局：优先显示应用和项目"), isOn: $codingLayout)
            Toggle(L("首页包含固定应用"), isOn: $includeFavoriteApps)
            Button { page = .projects } label: {
                Text(L("项目工作台")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            ShortcutSettingsView()
            Button(L("Dock 自动隐藏设置 ↗")) { SettingsDestination.desktop.open() }
            Text(L("在系统设置中开启自动隐藏 Dock，为代码和预览腾出空间；也可在那里恢复。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Picker(L("默认中心图标"), selection: $store.preferences.center) {
                Text(L("网络连接")).tag(CenterIndicator.network)
                Text(L("声音输出")).tag(CenterIndicator.sound)
            }
            Toggle(L("中心常驻输入法图标"), isOn: $inputSources.alwaysShow)
            Text(L("切换输入源后显示图标 2 秒，再恢复所选中心图标；开启常驻输入法时优先显示输入法。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(L("在圆环中显示")).font(.system(size: 13, weight: .semibold))
            Toggle(L("电池 · 外环"), isOn: $store.preferences.battery)
            Toggle(L("网络状态与提醒"), isOn: $store.preferences.wifi)
            Toggle(L("声音状态与音量"), isOn: $store.preferences.sound)
            Picker(L("底部显示"), selection: $store.preferences.bottomIndicator) {
                Text(L("状态提醒与音量四点")).tag(BottomIndicator.status)
                Text(L("电量百分比数字")).tag(BottomIndicator.batteryLevel)
                Text(L("音量百分比数字")).tag(BottomIndicator.volumeLevel)
            }
            Text(L("平时四点表示约 25%、50%、75%、100% 的音量；有提醒时替换为最重要的一项：严重低电、断网、低电、充电或静音。全部状态可在详情中查看。"))
                .font(.caption).foregroundStyle(.secondary)
            Text(L("选择数字后，圆环底部常显所选百分比，对应数据不可用时回落到提醒与四点。面板中的圆环按系统电池颜色着色：充电为绿色，严重低电为红色；菜单栏图标保持单色。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Toggle(L("悬停摘要包含蓝牙状态"), isOn: $store.preferences.bluetooth)
            HStack { Text(L("外观")); Spacer(); Text("Compact Orb").foregroundStyle(.secondary) }
            Toggle(L("登录时启动"), isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) }))
            if store.loginNeedsApproval {
                Button(L("在系统设置中批准登录启动")) { SMAppService.openSystemSettingsLoginItems() }.font(.caption)
            }
            Divider()
            Button { page = .system } label: {
                Text(L("系统功能")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            Button { appQuery = ""; runningOnly = false; page = .applications } label: {
                Text(L("管理常用应用")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            Button { page = .guide } label: {
                Text(L("如何隐藏原生菜单栏图标")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            Link(L("隐私政策"), destination: URL(string: "https://github.com/huanglizhuo/FuseBar/blob/main/docs/PRIVACY.md")!)
            Link(L("帮助与反馈"), destination: URL(string: "https://github.com/huanglizhuo/FuseBar/issues")!)
            Text(L("FuseBar %@ · 免费\n声音变化即时监听；其他状态约每 3 秒更新。", String(describing: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L("开发版"))))
                .font(.caption2).foregroundStyle(.secondary)
        }.toggleStyle(.checkbox).font(.system(size: 12)).padding(18)
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("把屏幕留给代码。")).font(.system(size: 21, weight: .semibold))
            HStack(spacing: 13) {
                ForEach(["wifi", StatusSymbols.bluetooth, "speaker.wave.2.fill", "battery.75percent"], id: \.self) { Image(systemName: $0) }
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                OrbView(snapshot: .normal, batteryRingTint: true).frame(width: 32, height: 32)
            }.frame(maxWidth: .infinity).padding(.vertical, 8).accessibilityHidden(true)
            Text(L("外环读电量，中心看 Wi-Fi 或个人热点。底部居中显示警告、充电或静音；正常时四点表示大致音量；不可读取音量时留空。蓝牙连接状态可在详情中查看。"))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { page = .system } label: {
                Text(L("系统功能")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            Button { onboardingComplete = true; page = .applications } label: {
                Text(L("管理常用应用")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            Button { onboardingComplete = true; page = .settings } label: {
                Text(L("快速打开快捷键")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle())
            Button(L("Dock 自动隐藏设置 ↗")) { SettingsDestination.desktop.open() }
            Text(L("保留重要状态，收起重复图标。"))
                .font(.system(size: 13, weight: .medium))
            Text(L("前往系统设置的“菜单栏”或“控制中心”，手动隐藏 Wi-Fi、蓝牙、声音和电池图标。先试用，再决定隐藏哪些。"))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("打开菜单栏设置")) { SettingsDestination.menuBar.open() }
            Button(L("开始使用")) { onboardingComplete = true; page = .status }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(18)
    }
}

struct OrbGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(L("FuseBar / 状态图谱")).font(.system(size: 24, weight: .semibold))
            Text(L("相同几何，真实尺寸与放大视图。图谱使用模拟状态，不读取或改变系统设置。"))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(140)), count: 4), spacing: 24) {
                ForEach(StatusSnapshot.scenarios, id: \.0) { title, snapshot in
                    VStack(spacing: 12) {
                        OrbView(snapshot: snapshot, batteryRingTint: true).frame(width: 66, height: 66)
                        OrbView(snapshot: snapshot, batteryRingTint: true).frame(width: 18, height: 18)
                        Text(title).font(.system(size: 12))
                    }.frame(width: 140, height: 145)
                }
            }
        }.padding(32).background(Color(nsColor: .windowBackgroundColor))
    }
}

struct InterfaceGallery: View {
    @ObservedObject var store: StatusStore
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(L("FuseBar / 按需展开")).font(.system(size: 26, weight: .semibold))
            Text(L("首次使用 → 状态详情 → 偏好设置 · 以下均为模拟状态预览"))
                .font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 24) {
                ForEach([PopoverView.Page.guide, .status, .settings], id: \.self) { page in
                    PopoverView(store: store, initialPage: page, preview: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                }
            }
        }.padding(32).background(Color(nsColor: .windowBackgroundColor))
    }
}
