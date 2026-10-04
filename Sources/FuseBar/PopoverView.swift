import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: StatusStore
    @ObservedObject private var inputSources: InputSourceStore
    private let onSelectInputSource: ((String) -> Void)?
    @StateObject private var shelf: ApplicationShelf
    @AppStorage("codingLayout") private var codingLayout = false
    @StateObject private var projects: CodingProjects
    @FocusState private var searchFocused: Bool
    @State private var searchIndex = 0
    @ObservedObject private var submenu = SideSubmenu.shared
    @StateObject private var files: FileShortcuts
    @StateObject private var bluetooth: BluetoothPanelStore
    @FocusState private var focusedStatus: Page?
    @FocusState private var focusedSource: String?
    private let focusSearch: Bool
    @State private var appQuery = ""
    @State private var frozenApplications: [ShelfApplication]?
    @State private var page: Page = .status
    @StateObject private var volumeEdit = VolumeEditModel()
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    /// True when this presentation opened because onboarding has not been seen yet.
    /// The durable flag is written on first appearance so even an Esc-dismiss counts.
    @State private var onboardingDue: Bool
    private let preview: Bool
    private let isSubmenu: Bool
    private let onOpenApplication: ((URL) -> Void)?
    private let onQuickAction: ((QuickAction) -> Void)?
    private let onOpenSettings: ((SettingsTab) -> Void)?
    private let searchKeys: SearchKeys?
    enum Page: Hashable { case battery, status, guide, sound, wifi, bluetooth, files, inputSources }

    init(store: StatusStore, initialPage: Page = .status, preview: Bool = false, initialQuery: String = "", isSubmenu: Bool = false, focusSearch: Bool = false, onSelectInputSource: ((String) -> Void)? = nil, onQuickAction: ((QuickAction) -> Void)? = nil, onOpenApplication: ((URL) -> Void)? = nil, onOpenSettings: ((SettingsTab) -> Void)? = nil, searchKeys: SearchKeys? = nil, shelf: ApplicationShelf? = nil) {
        _shelf = StateObject(wrappedValue: shelf ?? ApplicationShelf.shared)
        _projects = StateObject(wrappedValue: CodingProjects(defaults: store.defaults))
        _files = StateObject(wrappedValue: FileShortcuts(defaults: store.defaults))
        _bluetooth = StateObject(wrappedValue: preview ? BluetoothPanelStore(preview: true) : .shared)
        self.focusSearch = focusSearch
        self.onSelectInputSource = onSelectInputSource
        let sources = preview ? InputSourceStore(defaults: store.defaults) : InputSourceStore.shared
        if preview { sources.refresh() }
        _inputSources = ObservedObject(wrappedValue: sources)
        _codingLayout = AppStorage(wrappedValue: false, "codingLayout", store: store.defaults)
        self.store = store
        self.preview = preview
        self.isSubmenu = isSubmenu
        self.onQuickAction = onQuickAction
        self.onOpenApplication = onOpenApplication
        self.onOpenSettings = onOpenSettings
        self.searchKeys = searchKeys
        _page = State(initialValue: initialPage)
        _appQuery = State(initialValue: initialQuery)
        _onboardingComplete = AppStorage(wrappedValue: false, "onboardingComplete", store: store.defaults)
        _onboardingDue = State(initialValue: !store.defaults.bool(forKey: "onboardingComplete"))
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
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            let details = preview ? BatteryDetails(minutesToEmpty: 312) : SystemReader.batteryDetails()
                            VStack(alignment: .leading, spacing: 4) {
                                if let estimate = details.estimate(store.snapshot.battery) { Text(estimate) }
                                Text(details.lowPowerMode ? L("低电量模式已开启") : L("低电量模式未开启"))
                            }.font(.caption).foregroundStyle(.secondary)
                        }
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
            if page == .guide || (!preview && onboardingDue) {
                guide
                    .onAppear { if !preview && onboardingDue { onboardingComplete = true } }
            }
            else if page == .files { FileShortcutsView() }
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
                    Button { onOpenSettings?(.general) } label: {
                        Image(systemName: "gearshape").frame(width: 28, height: 28)
                    }.keyboardShortcut(",", modifiers: .command)
                        .help(L("设置…")).accessibilityLabel(L("设置…"))
                    Spacer()
                    Button { NSApplication.shared.terminate(nil) } label: {
                        Image(systemName: "power").frame(width: 28, height: 28)
                    }.keyboardShortcut("q").help(L("退出")).accessibilityLabel(L("退出"))
                }
                footerActions
            }.footerButtonChrome().padding(.horizontal, 18).padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .environment(\.locale, L10n.locale)
        .onAppear {
            volumeEdit.sync(store.snapshot.sound)
            store.refresh()
            if !preview {
                frozenApplications = liveApplications; shelf.refresh(); shelf.discoverApplications()
                bluetooth.refresh(state: store.snapshot.bluetooth.state)
            }
            if !preview || focusSearch { DispatchQueue.main.async { searchFocused = true } }
            searchKeys?.handler = { handleSearchKey($0) }
        }
        .onDisappear { searchKeys?.handler = nil }
        .onChange(of: page) { _, newPage in
            SideSubmenu.shared.close(); appQuery = ""; searchFocused = false; files.reload()
            // Home always comes back ready to type, as it does when the panel opens.
            if newPage == .status { DispatchQueue.main.async { searchFocused = true } }
            // Navigating away from the onboarding guide ends the guided first run.
            if newPage != .guide { onboardingDue = false }
        }
        .onChange(of: files.error) { _, error in if let error { store.errorMessage = error } }
        .onKeyPress(.leftArrow) {
            guard page != .status && page != .wifi && page != .sound else { return .ignored }
            page = .status
            return .handled
        }
        .onChange(of: codingLayout) { _, _ in SideSubmenu.shared.close() }
        .onChange(of: appQuery) { _, _ in SideSubmenu.shared.close() }
        .onChange(of: store.snapshot.sound) { _, sound in
            if !volumeEdit.editing { volumeEdit.sync(sound) }
        }
        .onChange(of: store.snapshot.bluetooth) { _, status in if !preview { bluetooth.refresh(state: status.state) } }
    }

    private var footerActions: some View {
        HStack(spacing: 6) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Button { onQuickAction?(action) } label: {
                    StatusIcon(name: action.symbol).frame(width: 28, height: 28)
                }.help(action.title).accessibilityLabel(action.title)
                    .disabled(!preview && onQuickAction == nil)
            }
            Button { page = .files } label: {
                Image(systemName: "folder").frame(width: 28, height: 28)
            }.help(L("文件夹")).accessibilityLabel(L("文件夹"))

        }.footerButtonChrome()
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
            .menuRowFocus(.inputSources, focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
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
            }.frame(height: isSubmenu ? menuListHeight(count: inputSources.sources.count, rowHeight: 46, cap: 240) : 240)
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
            // The file and bundle names find localized apps by English name: Terminal → 终端, vscode.
            return MenuSearchEntry(id: "app:" + app.id, title: app.name, category: L("应用"), symbol: "app", destination: .application(url),
                                   aliases: [url.deletingPathExtension().lastPathComponent, app.id.components(separatedBy: ".").last ?? ""])
        }
        // Devices and sources name the action Return performs, so a result never surprises.
        let outputs = store.audioOutputs.map { output in
            MenuSearchEntry(id: "output:" + output.id, title: output.name,
                            category: output.selected ? L("当前输出") : output.bluetoothAddress == nil ? L("切换输出") : L("连接输出"),
                            symbol: output.symbol, destination: .audioOutput(output.id))
        }
        let sources = inputSources.sources.map { source in
            MenuSearchEntry(id: "source:" + source.id, title: source.name,
                            category: source.id == inputSources.currentID ? L("当前输入源") : L("切换输入源"),
                            symbol: "keyboard", destination: .inputSource(source.id))
        }
        let devices = bluetooth.devices.map { device in
            MenuSearchEntry(id: "bluetooth:" + device.id, title: device.name, category: device.connected ? L("断开设备") : L("连接设备"),
                            symbol: device.symbol, destination: .bluetoothDevice(device.id))
        }
        let projectEntries = projects.items.map {
            MenuSearchEntry(id: "project:" + $0.id.uuidString, title: $0.name, category: L("项目"), symbol: "hammer", destination: .project($0.id))
        }
        let shortcuts = files.items.map {
            MenuSearchEntry(id: "file:" + $0.id.uuidString, title: $0.name, category: L("文件与文件夹"), symbol: "doc.on.doc", destination: .file($0.id))
        }
        let panes = SettingsDestination.searchable.map {
            MenuSearchEntry(id: "settings:" + $0.destination.rawValue, title: $0.title, category: L("系统设置"), symbol: $0.symbol,
                            destination: .settings($0.destination), aliases: [$0.keyword])
        }
        let actions: [(String, String, String)] = [
            ("battery", L("电池"), "battery.100percent"), ("wifi", "Wi-Fi", "wifi"),
            ("sound", L("声音输出"), "speaker.wave.2"), ("bluetooth", L("蓝牙"), StatusSymbols.bluetooth),
            ("inputSources", L("输入源"), "keyboard"), ("settings", L("设置…"), "gearshape"),
            ("files", L("文件与文件夹"), "folder"), ("projects", L("项目工作台"), "hammer"),
            ("applications", L("应用启动器"), "square.grid.3x3"), ("windows", L("所有窗口"), "rectangle.3.group")]
        return apps + outputs + sources + devices + projectEntries + shortcuts + panes + actions.map {
            // The English key keeps actions findable in every interface language ("sound" → 声音输出).
            MenuSearchEntry(id: "action:" + $0.0, title: $0.1, category: L("操作"), symbol: $0.2, destination: .action($0.0), aliases: [$0.0])
        }
    }
    private var searchMatches: [MenuSearchEntry] {
        MenuSearchModel.results(searchEntries, query: appQuery)
    }
    private var showingSearchResults: Bool {
        !appQuery.isEmpty
    }

    private var searchField: some View {
        TextField(L("搜索应用、设备与设置…"), text: $appQuery)
            .textFieldStyle(.roundedBorder).focused($searchFocused)
            .accessibilityLabel(L("搜索应用、设备与设置…"))
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

    /// ↑/↓ move through the results and Return opens the selection, even while an input method is
    /// composing. Without results the keys stay with the field, so the input method can still use them.
    private func handleSearchKey(_ key: SearchKeys.Key) -> Bool {
        guard page == .status, !appQuery.isEmpty else { return false }
        let count = searchMatches.count
        guard count > 0 else { return false }
        switch key {
        case .up: searchIndex = max(0, searchIndex - 1)
        case .down: searchIndex = min(searchIndex + 1, count - 1)
        case .open: openSearchSelection()
        }
        return true
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
        case .audioOutput(let id):
            // Select first: the submenu's own refresh must not claim the audio queue before the switch.
            if let output = store.audioOutputs.first(where: { $0.id == id }), !output.selected { store.selectAudioOutput(output) }
            openSubmenu(.sound, anchor: searchAnchor(entry))
        case .bluetoothDevice(let id):
            if let device = bluetooth.devices.first(where: { $0.id == id }) {
                bluetooth.setConnected(device, connected: !device.connected, state: store.snapshot.bluetooth.state) {
                    store.refresh(); store.refreshAudioOutputs()
                }
            }
            // The submenu shares the store, so it shows the row's progress and verified result.
            openSubmenu(.bluetooth, anchor: searchAnchor(entry))
        case .inputSource(let id): onSelectInputSource?(id)
        case .project(let id):
            guard let project = projects.items.first(where: { $0.id == id }) else { return }
            projects.selectedID = id
            projects.open(project)
        case .settings(let destination): destination.open()
        case .action(let id):
            let statusPages: [String: Page] = ["battery": .battery, "wifi": .wifi, "sound": .sound, "bluetooth": .bluetooth, "inputSources": .inputSources]
            if let destination = statusPages[id] {
                openSubmenu(destination, anchor: searchAnchor(entry))
                return
            }
            searchFocused = false
            appQuery = ""
            switch id {
            case "settings": onOpenSettings?(.general)
            case "files": page = .files
            case "projects": onOpenSettings?(.projects)
            case "applications": onQuickAction?(.applications)
            case "windows": onQuickAction?(.allWindows)
            default: break
            }
        }
    }

    private func searchAnchor(_ entry: MenuSearchEntry) -> String {
        "search:" + entry.id.replacingOccurrences(of: "action:", with: "")
    }

    private func searchResultButton(_ entry: MenuSearchEntry, index: Int) -> some View {
        let anchor = searchAnchor(entry)
        return Button { performSearchEntry(entry) } label: {
            HStack(spacing: 10) {
                if case .application(let url) = entry.destination {
                    ApplicationIcon(url: url).frame(width: 28, height: 28)
                } else if case .inputSource(let id) = entry.destination, let source = inputSources.sources.first(where: { $0.id == id }) {
                    InputSourceGlyph(source: source).frame(width: 28, height: 28)
                } else {
                    StatusIcon(name: entry.symbol).frame(width: 28, height: 28)
                }
                Text(entry.title).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                Text(entry.category).font(.caption2).foregroundStyle(.secondary)
            }.font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(MenuButtonStyle(selected: index == searchIndex || submenu.selection == anchor))
            .background(SideSubmenuAnchor(id: anchor))
            .onKeyPress(.rightArrow) { performSearchEntry(entry); return .handled }
            .help(entry.title).accessibilityLabel(entry.title)
            .accessibilityValue(index == searchIndex ? L("已选择") : "")
    }

    private var searchResults: some View {
        let matches = searchMatches
        return VStack(alignment: .leading, spacing: 6) {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, entry in
                            searchResultButton(entry, index: index).id(index)
                        }
                        if matches.isEmpty { Text(L("没有匹配结果")).font(.caption).padding(8) }
                    }
                }.frame(height: menuListHeight(count: matches.count, rowHeight: 36, cap: 220))
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
                    .menuRowFocus(.battery, focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
                Button { openSubmenu(.wifi) } label: { Image(systemName: StatusSymbols.wifi(store.snapshot.wifi)) }.help(store.snapshot.wifi.detail).background(SideSubmenuAnchor(id: "wifi"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "wifi", inset: 6))
                    .menuRowFocus(.wifi, focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
                    .accessibilityLabel("Wi-Fi")
                Button { openSubmenu(.sound) } label: { Image(systemName: StatusSymbols.sound(store.snapshot.sound)) }.help(store.snapshot.sound.detail).background(SideSubmenuAnchor(id: "sound"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "sound", inset: 6))
                    .menuRowFocus(.sound, focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
                    .accessibilityLabel(L("声音"))
                Button { openSubmenu(.bluetooth) } label: { StatusIcon(name: StatusSymbols.bluetooth, size: 15, weight: .medium) }.help(store.snapshot.bluetooth.detail).background(SideSubmenuAnchor(id: "bluetooth"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "bluetooth", inset: 6))
                    .menuRowFocus(.bluetooth, focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
                    .accessibilityLabel(L("蓝牙"))
                Button { openSubmenu(.inputSources) } label: {
                    if let current = inputSources.current { InputSourceGlyph(source: current).frame(width: 14, height: 14) }
                    else { Image(systemName: "keyboard") }
                }.help(L("切换输入源")).accessibilityLabel(L("输入源")).background(SideSubmenuAnchor(id: "inputSources"))
                    .buttonStyle(MenuButtonStyle(selected: submenu.selection == "inputSources", inset: 6))
                    .menuRowFocus(.inputSources, focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
            }.controlSize(.small).foregroundStyle(.primary).padding(.horizontal, 18).padding(.bottom, 10)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("项目工作台")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { onOpenSettings?(.projects) } label: { Image(systemName: "pencil") }.buttonStyle(.plain)
                        .accessibilityLabel(L("项目工作台"))
                }
                if let current = projects.current {
                    Picker(L("当前项目"), selection: $projects.selectedID) {
                        ForEach(projects.items) { project in Text(project.name).tag(Optional(project.id)) }
                    }.labelsHidden()
                    HStack {
                        Button(current.opener.map(CodingProject.openerName) ?? L("目录")) { projects.openFolder(current) }
                            .disabled(current.folder == nil)
                        Button(L("预览")) { projects.openWeb(current.preview) }.disabled(current.preview.isEmpty)
                        Button(L("仓库")) { projects.openWeb(current.repository) }.disabled(current.repository.isEmpty)
                    }.controlSize(.small)
                } else {
                    Button(L("添加项目入口")) { onOpenSettings?(.projects) }
                }
                if let error = projects.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(18)

        }
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
                          symbol: store.snapshot.bluetooth.state == .off ? StatusSymbols.bluetoothOff : StatusSymbols.bluetooth,
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
            HStack(spacing: 12) {
                MuteButton(sound: store.snapshot.sound, store: store,
                           iconFont: .system(size: 14, weight: .medium), iconSize: 24)
                Slider(value: volumeEdit.binding(sound: store.snapshot.sound, store: store), in: 0...1,
                       onEditingChanged: { volumeEdit.setEditing($0, sound: store.snapshot.sound, store: store) })
                    .frame(minWidth: 80)
                    .disabled(store.audioBusy || !store.snapshot.sound.canSetVolume)
                    .accessibilityLabel(L("输出音量"))
                    .accessibilityValue("\(volumePercent(volumeEdit.volume))%")
                Button { openSubmenu(.sound) } label: {
                    HStack(spacing: 4) {
                        Text(store.snapshot.sound.available ? store.snapshot.sound.deviceName : store.snapshot.sound.detail)
                            .font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }.buttonStyle(MenuButtonStyle(selected: submenu.selection == "sound", inset: 4))
                    .help(fullStatusDetail(.sound))
                    .accessibilityLabel(L("声音") + ": " + fullStatusDetail(.sound))
                    .menuRowFocus(statusPage(.sound), focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
            }.padding(.horizontal, 16).padding(.bottom, 12)
            .background(SideSubmenuAnchor(id: "sound"))
            if store.snapshot.sound.muted == true {
                MutedNotice().padding(.horizontal, 18).padding(.bottom, 10)
            }
        }
    }

    private var liveApplications: [ShelfApplication] {
        ApplicationShelfModel.home(running: shelf.running, recentIDs: shelf.recentIDs, frontmostID: shelf.frontmostID)
    }

    private var runningApplications: some View {
        // Positions freeze while the panel is open: launches append, quits close the gap.
        let apps = frozenApplications.map { ApplicationShelfModel.stable(previous: $0, current: liveApplications) } ?? liveApplications
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("运行中的应用")).font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            if apps.isEmpty {
                Text(L("暂无运行中的应用")).font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 5) {
                    ForEach(Array(apps.prefix(12).enumerated()), id: \.element.id) { index, app in
                        Button { if let url = app.url { onOpenApplication?(url) } } label: {
                            Group {
                                if let url = app.url {
                                    ApplicationIcon(url: url).frame(width: 28, height: 28)
                                } else { Image(systemName: "app.dashed").frame(width: 28, height: 28) }
                            }.frame(width: 38, height: 34)
                                .background(shelf.frontmostID == app.id ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(alignment: .bottom) {
                                    if app.running { Circle().fill(.secondary).frame(width: 3, height: 3) }
                                }.contentShape(Rectangle())
                        }.buttonStyle(MenuButtonStyle())
                            .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command) : nil)
                            .help(index < 9 ? "\(app.name)  ⌘\(index + 1)" : app.name).accessibilityLabel(L("打开 %@", app.name))
                            .accessibilityValue(shelf.frontmostID == app.id ? L("当前应用") : L("正在运行"))
                            .contextMenu { applicationMenu(app) }
                            .disabled(app.url == nil || (!preview && onOpenApplication == nil))
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 8)
    }

    @ViewBuilder private func applicationMenu(_ app: ShelfApplication) -> some View {
            if app.running {
                Button(L("隐藏应用")) { store.errorMessage = shelf.setHidden(true, app: app) }
                Button(L("显示应用")) { store.errorMessage = shelf.setHidden(false, app: app) }
                Button(L("强制退出")) { store.errorMessage = shelf.forceTerminate(app) }
                Divider()
            }
            Button(L("在 Finder 中显示")) {
                if let url = app.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }.disabled(app.url == nil)
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
                StatusIcon(name: symbol, size: 14, weight: .medium).frame(width: 20).foregroundStyle(.primary)
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
            .menuRowFocus(statusPage(destination), focus: $focusedStatus, open: { openSubmenu($0) }, move: moveStatusFocus)
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
        case .wifi: return store.snapshot.wifi.connection == .disconnected || store.snapshot.wifi.pathUnavailable
        default: return false
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("把屏幕留给代码。")).font(.system(size: 21, weight: .semibold))
            OrbMorphHero(snapshot: .hero, preview: preview)
                .frame(height: 48)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            Text(L("保留重要状态，收起重复图标。")).font(.headline)
            Text(L("前往系统设置的“菜单栏”或“控制中心”，手动隐藏 Wi-Fi、蓝牙、声音和电池图标。先试用，再决定隐藏哪些。"))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("打开菜单栏设置")) { SettingsDestination.menuBar.open() }
            Divider()
            // The shortcut is the main way back once the Dock is hidden; offer it on the first run.
            ShortcutSettingsView()
            Divider()
            Text(L("直接输入即可搜索")).font(.headline)
            Text(L("输入应用名（支持拼音）、设备名（如 AirPods）或系统设置（如“显示器”），按回车执行。⌘1–⌘9 打开前 9 个应用。"))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("开始使用")) { finishGuide() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(18)
    }

    /// The first-run guide is drawn over `.status`, so assigning the page alone would not leave it.
    private func finishGuide() {
        onboardingDue = false
        page = .status
        DispatchQueue.main.async { searchFocused = true }
    }
}

/// Search navigation keys, taken by the app's event monitor before the field editor: a composing
/// pinyin input method would otherwise claim ↑/↓/Return for its candidate window.
@MainActor final class SearchKeys {
    enum Key { case up, down, open }
    var handler: ((Key) -> Bool)?

    static func key(for event: NSEvent) -> Key? {
        guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return nil }
        switch event.keyCode {
        case 126: return .up
        case 125: return .down
        case 36, 76: return .open // Return and keypad Enter
        default: return nil
        }
    }
}

private extension View {
    /// Shared chrome for the bar of footer icon buttons.
    func footerButtonChrome() -> some View {
        buttonStyle(MenuButtonStyle()).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
    }

    /// Standard keyboard navigation for status rows: → and Return open the row's
    /// submenu; ↑ and ↓ move focus through the status rows in layout order.
    func menuRowFocus(_ page: PopoverView.Page, focus: FocusState<PopoverView.Page?>.Binding,
                      open: @escaping (PopoverView.Page) -> Void,
                      move: @escaping (PopoverView.Page, Int) -> Void) -> some View {
        focusable().focused(focus, equals: page)
            .onKeyPress(.rightArrow) { open(page); return .handled }
            .onKeyPress(.return) { open(page); return .handled }
            .onKeyPress(.downArrow) { move(page, 1); return .handled }
            .onKeyPress(.upArrow) { move(page, -1); return .handled }
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
                ForEach([PopoverView.Page.guide, .status], id: \.self) { page in
                    PopoverView(store: store, initialPage: page, preview: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                }
                SettingsView(store: store, preview: true)
            }
        }.padding(32).background(Color(nsColor: .windowBackgroundColor))
    }
}
