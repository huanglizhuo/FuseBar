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
    private let focusSearch: Bool
    @State private var appQuery = ""
    @State private var runningOnly = false
    @State private var page: Page = .status
    @State private var editingVolume = false
    @State private var volume = 0.0
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    private let preview: Bool
    private let onOpenApplication: ((URL) -> Void)?
    private let onQuickAction: ((QuickAction) -> Void)?
    enum Page { case status, settings, guide, applications, sound, wifi, bluetooth, files, system, projects, inputSources }

    init(store: StatusStore, initialPage: Page = .status, preview: Bool = false, focusSearch: Bool = false, onSelectInputSource: ((String) -> Void)? = nil, onQuickAction: ((QuickAction) -> Void)? = nil, onOpenApplication: ((URL) -> Void)? = nil, shelf: ApplicationShelf? = nil) {
        _shelf = StateObject(wrappedValue: shelf ?? ApplicationShelf.shared)
        _projects = StateObject(wrappedValue: CodingProjects(defaults: store.defaults))
        self.focusSearch = focusSearch
        self.onSelectInputSource = onSelectInputSource
        let sources = preview ? InputSourceStore(defaults: store.defaults) : InputSourceStore.shared
        if preview { sources.refresh() }
        _inputSources = ObservedObject(wrappedValue: sources)
        _codingLayout = AppStorage(wrappedValue: false, "codingLayout", store: store.defaults)
        _includeFavoriteApps = AppStorage(wrappedValue: true, "includeFavoriteApps", store: store.defaults)
        self.store = store
        self.preview = preview
        self.onQuickAction = onQuickAction
        self.onOpenApplication = onOpenApplication
        _page = State(initialValue: initialPage)
    }

    var body: some View {
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
                    OrbView(snapshot: store.snapshot, preferences: store.preferences).frame(width: 26, height: 26)
                        .accessibilityHidden(true)
                    Text("FuseBar").font(.system(size: 17, weight: .semibold))
                    Spacer(minLength: 4)
                    Button { page = .guide } label: {
                        Image(systemName: "questionmark.circle").frame(width: 24, height: 24)
                    }.buttonStyle(.borderless).help(L("图标说明与使用引导"))
                        .accessibilityLabel(L("图标说明与使用引导"))
                }
                Text(store.snapshot.headline(store.preferences)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(18)
            Divider()
            if page == .settings { ScrollView { settings }.frame(height: 420) }
            else if page == .guide || (!preview && !onboardingComplete) { ScrollView { guide }.frame(height: 420) }
            else if page == .applications { applications }
            else if page == .sound { soundOutputs }
            else if page == .wifi { WiFiPanel(store: store) }
            else if page == .bluetooth { BluetoothPanel(store: store) }
            else if page == .files { FileShortcutsView() }
            else if page == .system { SystemControlsView(store: store) }
            else if page == .projects { ProjectEditorView(projects: projects) }
            else if page == .inputSources { inputSourceList }
            else {
                VStack(spacing: 0) {
                    runningApplications
                    searchField
                    if !appQuery.isEmpty { searchResults }
                    else if codingLayout { codingHome }
                    else { status }
                }
            }
            if let error = store.errorMessage {
                HStack(alignment: .top) {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel(L("关闭错误提示"))
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            Divider()
            ZStack {
                HStack {
                    Button { page = .settings; store.refreshLoginStatus() } label: {
                        Image(systemName: "gearshape").frame(width: 24, height: 24)
                    }.keyboardShortcut(",", modifiers: .command).disabled(page == .settings)
                        .help(L("设置…")).accessibilityLabel(L("设置…"))
                    Spacer()
                    Button(L("退出")) { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                }
                footerActions
            }.buttonStyle(.borderless).font(.caption).padding(.horizontal, 18).padding(.vertical, 10)
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .environment(\.locale, L10n.locale)
        .onAppear {
            volume = Double(store.snapshot.sound.volume ?? 0)
            store.refresh()
            if !preview { shelf.refresh(); shelf.discoverApplications() }
            if focusSearch { DispatchQueue.main.async { searchFocused = true } }
        }
        .onChange(of: store.snapshot.sound.volume) { _, value in
            if !editingVolume { volume = Double(value ?? 0) }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 4) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Button { onQuickAction?(action) } label: {
                    Image(systemName: action.symbol).frame(width: 24, height: 24)
                }.help(action.title).accessibilityLabel(action.title)
                    .disabled(!preview && onQuickAction == nil)
            }
            Button { page = .files } label: {
                Image(systemName: "folder").frame(width: 24, height: 24)
            }.help(L("文件夹")).accessibilityLabel(L("文件夹"))

        }.buttonStyle(.borderless).font(.system(size: 12))
    }

    private var inputSourcePicker: some View {
        Button { page = .inputSources } label: {
            HStack(spacing: 12) {
                Group {
                    if let current = inputSources.current { InputSourceGlyph(source: current) }
                    else { Image(systemName: "keyboard").font(.system(size: 16)).foregroundStyle(.secondary) }
                }.frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("输入源")).font(.system(size: 12, weight: .medium))
                    Text(inputSources.current?.name ?? L("输入源未知"))
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 18).padding(.vertical, 13).contentShape(Rectangle())
        }.buttonStyle(.plain).help(L("切换输入源"))
    }

    private var inputSourceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("输入源")).font(.headline)
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
                        }.buttonStyle(.plain).disabled(!preview && onSelectInputSource == nil)
                    }
                }
            }.frame(height: 240)
        }.padding(18).onAppear { if !preview { inputSources.refresh() } }
    }

    private var searchMatches: [ShelfApplication] {
        Array(ApplicationShelfModel.visible(shelf.searchable, query: appQuery).prefix(50))
    }

    private var searchField: some View {
        TextField(L("搜索应用…"), text: $appQuery)
            .textFieldStyle(.roundedBorder).focused($searchFocused)
            .onChange(of: appQuery) { _, _ in searchIndex = 0 }
            .onSubmit { openSearchSelection() }
            .onKeyPress(.downArrow) {
                searchIndex = min(searchIndex + 1, max(0, searchMatches.count - 1)); return .handled
            }
            .onKeyPress(.upArrow) { searchIndex = max(0, searchIndex - 1); return .handled }
            .padding(.horizontal, 18).padding(.vertical, 10)
    }

    private func openSearchSelection() {
        guard !appQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              searchMatches.indices.contains(searchIndex), let url = searchMatches[searchIndex].url else { return }
        onOpenApplication?(url)
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack {
                        ForEach(Array(searchMatches.enumerated()), id: \.element.id) { index, app in
                            applicationRow(app).padding(5)
                                .background(index == searchIndex ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .id(index)
                        }
                        if searchMatches.isEmpty { Text(L("没有匹配的应用。")).font(.caption) }
                    }
                }.frame(height: 220)
                .onChange(of: searchIndex) { _, index in reader.scrollTo(index) }
            }
            Text(L("搜索常用安装目录和已固定应用；其他位置可手动添加。"))
                .font(.caption2).foregroundStyle(.secondary)
            Button(L("添加应用")) { store.errorMessage = shelf.addApplication() }
        }.padding(18)
    }

    private var codingHome: some View {
        VStack(spacing: 0) {
            HStack {
                Button { SettingsDestination.battery.open() } label: {
                    Label(store.snapshot.battery.availability == .available ? "\(store.snapshot.battery.level)%" : "—", systemImage: StatusSymbols.battery(store.snapshot.battery))
                }.help(store.snapshot.battery.detail)
                Button { page = .wifi } label: { Image(systemName: StatusSymbols.wifi(store.snapshot.wifi)) }.help(store.snapshot.wifi.detail)
                    .accessibilityLabel("Wi-Fi")
                Button { page = .sound } label: { Image(systemName: StatusSymbols.sound(store.snapshot.sound)) }.help(store.snapshot.sound.detail)
                    .accessibilityLabel(L("声音"))
                Button { page = .bluetooth } label: { Image(systemName: StatusSymbols.bluetooth) }.help(store.snapshot.bluetooth.detail)
                    .accessibilityLabel(L("蓝牙"))
                Button { page = .inputSources } label: {
                    if let current = inputSources.current { InputSourceGlyph(source: current).frame(width: 14, height: 14) }
                    else { Image(systemName: "keyboard") }
                }.help(L("切换输入源")).accessibilityLabel(L("输入源"))
            }.controlSize(.small).padding(.horizontal, 18).padding(.bottom, 10)
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
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 28, height: 28)
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
            }.buttonStyle(.plain).disabled(app.url == nil || onOpenApplication == nil)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("声音输出")).font(.headline)
                Spacer()
                if store.audioBusy { ProgressView().controlSize(.small) }
                Button(L("刷新")) { store.refreshAudioOutputs() }.disabled(store.audioBusy)
            }
            Toggle(L("静音"), isOn: Binding(get: { store.snapshot.sound.muted == true }, set: { store.setMuted($0) }))
                .disabled(store.audioBusy || !store.snapshot.sound.canSetMute)
            if !store.snapshot.sound.canSetMute {
                Text(L("此设备不支持软件静音。")).font(.caption2).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 6) {
                    if store.audioOutputs.isEmpty && !store.audioBusy {
                        Text(L("没有可用的输出设备。请检查连接，或打开声音设置。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(store.audioOutputs) { output in
                        Button { store.selectAudioOutput(output) } label: {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                Text(output.name).lineLimit(2)
                                Spacer()
                                if output.selected { Image(systemName: "checkmark") }
                            }.padding(10).frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(store.audioBusy)
                            .accessibilityValue(output.selected ? L("当前输出") : "")
                    }
                }
            }.frame(height: 230)
            Text(L("切换媒体播放输出；系统提示音仍使用原来的设置。"))
                .font(.caption2).foregroundStyle(.secondary)
            Button(L("打开声音设置…")) { SettingsDestination.sound.open() }
        }.padding(18)
        .onAppear { if !preview { store.refreshAudioOutputs() } }
    }

    private var status: some View {
        VStack(spacing: 0) {
            statusRow(L("电池"), detail: store.snapshot.battery.detail, symbol: StatusSymbols.battery(store.snapshot.battery), destination: .battery)
            Divider().padding(.leading, 48)
            statusRow("Wi-Fi", detail: store.snapshot.wifi.detail, symbol: StatusSymbols.wifi(store.snapshot.wifi), destination: .wifi)
            if store.snapshot.wifi.shouldOfferNameAuthorization(store.networkNameAccess) {
                VStack(alignment: .leading, spacing: 5) {
                    Button(store.networkNameAccess == .blocked ? L("检查定位权限…") : L("显示网络名称…")) { store.requestNetworkName() }.font(.caption)
                    Text(L("需 macOS 定位授权；不会采集位置。"))
                        .font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 48).padding(.bottom, 12)
            }
            Divider().padding(.leading, 48)
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
            Divider().padding(.leading, 48)
            inputSourcePicker
            Divider().padding(.leading, 48)
            statusRow(L("声音"), detail: store.snapshot.sound.detail,
                      symbol: StatusSymbols.sound(store.snapshot.sound), destination: .sound)
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.secondary)
                Slider(value: Binding(get: { volume }, set: { value in
                    volume = value
                    store.setVolume(value)
                }), in: 0...1, onEditingChanged: { editing in
                    editingVolume = editing
                    if !editing { store.setVolume(volume) }
                })
                .disabled(!store.snapshot.sound.canSetVolume)
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 8) {
                    ForEach(Array(apps.prefix(apps.count > 12 ? 11 : 12))) { app in
                        Button { if let url = app.url { onOpenApplication?(url) } } label: {
                            Group {
                                if let url = app.url {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 28, height: 28)
                                } else { Image(systemName: "app.dashed").frame(width: 28, height: 28) }
                            }.frame(width: 38, height: 34)
                                .background(shelf.frontmostID == app.id ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(alignment: .bottom) {
                                    if app.running { Circle().fill(.secondary).frame(width: 3, height: 3) }
                                }.contentShape(Rectangle())
                        }.buttonStyle(.plain).help(app.name).accessibilityLabel(L("打开 %@", app.name))
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
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 12)
    }

    private func statusRow(_ title: String, detail: String, symbol: String, destination: SettingsDestination) -> some View {
        Button {
            if destination == .sound { page = .sound }
            else if destination == .wifi { page = .wifi }
            else if destination == .bluetooth { page = .bluetooth }
            else { destination.open() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16)).frame(width: 20).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: destination == .battery ? "arrow.up.forward" : "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 18).padding(.vertical, 13).contentShape(Rectangle())
        }.buttonStyle(.plain).help(destination == .battery ? L("打开电池系统设置") : L("打开%@面板", title))
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("编码工作台")).font(.headline)
            Toggle(L("编码布局：优先显示应用和项目"), isOn: $codingLayout)
            Toggle(L("首页包含固定应用"), isOn: $includeFavoriteApps)
            Button(L("项目工作台")) { page = .projects }
            ShortcutSettingsView()
            Button(L("Dock 自动隐藏设置 ↗")) { SettingsDestination.desktop.open() }
            Text(L("在系统设置中开启自动隐藏 Dock，为代码和预览腾出空间；也可在那里恢复。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Toggle(L("中心常驻输入法图标"), isOn: $inputSources.alwaysShow)
            Text(L("默认切换输入源后显示图标 2 秒，再恢复 Wi-Fi；输入法内部的中英文模式可能无法识别。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(L("在圆环中显示")).font(.system(size: 13, weight: .semibold))
            Toggle(L("电池 · 外环"), isOn: $store.preferences.battery)
            Toggle(L("Wi-Fi · 中心"), isOn: $store.preferences.wifi)
            Toggle(L("声音 · 四点音量与静音"), isOn: $store.preferences.sound)
            Text(L("平时四点表示约 25%、50%、75%、100% 的音量；有提醒时替换为最重要的一项：严重低电、断网、低电、充电或静音。全部状态可在详情中查看。"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle(L("悬停摘要包含蓝牙状态"), isOn: $store.preferences.bluetooth)
            HStack { Text(L("外观")); Spacer(); Text("Compact Orb").foregroundStyle(.secondary) }
            Toggle(L("登录时启动"), isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) }))
            if store.loginNeedsApproval {
                Button(L("在系统设置中批准登录启动")) { SMAppService.openSystemSettingsLoginItems() }.font(.caption)
            }
            Divider()
            Button(L("系统功能")) { page = .system }
            Button(L("管理常用应用")) { appQuery = ""; runningOnly = false; page = .applications }
            Button(L("如何隐藏原生菜单栏图标")) { page = .guide }
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
                OrbView(snapshot: .normal).frame(width: 32, height: 32)
            }.frame(maxWidth: .infinity).padding(.vertical, 8).accessibilityHidden(true)
            Text(L("外环读电量，中心看 Wi-Fi 或个人热点。底部居中显示警告、充电或静音；正常时四点表示大致音量；不可读取音量时留空。蓝牙连接状态可在详情中查看。"))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(L("系统功能")) { page = .system }
            Button(L("管理常用应用")) { onboardingComplete = true; page = .applications }
            Button(L("快速打开快捷键")) { onboardingComplete = true; page = .settings }
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
                        OrbView(snapshot: snapshot).frame(width: 66, height: 66)
                        OrbView(snapshot: snapshot).frame(width: 18, height: 18)
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
