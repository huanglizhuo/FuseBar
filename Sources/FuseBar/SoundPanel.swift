import SwiftUI

/// Volume slider state shared by the sound panel and the home sound row: it keeps
/// the slider honest while the output device changes mid-edit.
@MainActor
final class VolumeEditModel: ObservableObject {
    @Published private(set) var volume: Double = 0
    private(set) var editing = false
    private(set) var deviceUID: String?

    func sync(_ sound: SoundStatus) {
        volume = Double(sound.volume ?? 0)
        deviceUID = sound.deviceUID
    }

    func binding(sound: SoundStatus, store: StatusStore) -> Binding<Double> {
        Binding(get: { self.volume }, set: { value in
            guard self.deviceUID == sound.deviceUID else { return }
            self.volume = value
            store.setVolume(value)
        })
    }

    func setEditing(_ editing: Bool, sound: SoundStatus, store: StatusStore) {
        self.editing = editing
        if !editing, deviceUID != sound.deviceUID || store.errorMessage != nil { sync(sound) }
    }
}

/// The mute toggle shared by the sound panel and the home sound row; the two sites
/// only differ in icon size.
struct MuteButton: View {
    let sound: SoundStatus
    @ObservedObject var store: StatusStore
    var iconFont: Font? = nil
    var iconSize: CGFloat = 26

    var body: some View {
        Button { store.setMuted(sound.muted != true) } label: {
            Image(systemName: sound.muted == true ? "speaker.slash.fill" : "speaker.fill")
                .font(iconFont).frame(width: iconSize, height: iconSize)
        }.buttonStyle(MenuButtonStyle(selected: sound.muted == true))
            .disabled(store.audioBusy || !sound.canSetMute)
            .help(L("静音")).accessibilityLabel(L("静音"))
            .accessibilityValue(sound.muted == true ? L("已开启") : L("已关闭"))
    }
}

/// Caption shown while system mute is on.
struct MutedNotice: View {
    var body: some View {
        Text(L("系统静音已开启；调整音量不会自动取消静音。"))
            .font(.caption2).foregroundStyle(.secondary)
    }
}

struct SoundPanel: View {
    @ObservedObject var store: StatusStore
    var preview = false
    var isSubmenu = false
    @StateObject private var volumeEdit = VolumeEditModel()

    private var sound: SoundStatus { store.snapshot.sound }
    private var outputs: [AudioOutput] { store.audioOutputs }

    var body: some View {
        VStack(spacing: 0) {
            SystemMenuHeader(title: L("声音"), closesSubmenu: isSubmenu) {
                if store.audioBusy { ProgressView().controlSize(.small) }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(sound.available ? sound.deviceName : sound.detail)
                        .lineLimit(1).help(sound.detail)
                    Spacer(minLength: 4)
                    Text(sound.volume == nil ? "—" : "\(volumePercent(volumeEdit.volume))%")
                        .monospacedDigit().foregroundStyle(.secondary)
                }.font(.system(size: 12))
                HStack(spacing: 8) {
                    MuteButton(sound: sound, store: store)
                    Slider(value: volumeEdit.binding(sound: sound, store: store), in: 0...1,
                           onEditingChanged: { volumeEdit.setEditing($0, sound: sound, store: store) })
                        .disabled(store.audioBusy || !sound.canSetVolume)
                        .accessibilityLabel(L("输出音量"))
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                }
                if sound.muted == true {
                    MutedNotice()
                } else if sound.available && !sound.canSetVolume {
                    Text(L("此设备由硬件控制音量。")).font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
            Divider().padding(.horizontal, 16)
            HStack {
                Text(L("输出设备")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                MenuRefreshButton(title: L("刷新"), disabled: store.audioBusy) { store.refreshAudioOutputs() }
            }.padding(.horizontal, 16).padding(.top, 6)
            if outputs.isEmpty {
                MenuNotice(text: store.audioBusy ? L("正在读取设备…") : L("没有可用的输出设备。请检查连接，或打开声音设置。"))
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(outputs) { output in
                            MenuListRow(action: { if !output.selected { store.selectAudioOutput(output) } },
                                        selected: output.selected,
                                        disabled: store.audioBusy || volumeEdit.editing,
                                        leading: { DeviceMenuIcon(symbol: output.symbol, selected: output.selected) },
                                        title: { Text(output.name).font(.system(size: 13)).lineLimit(1).truncationMode(.middle) },
                                        trailing: {
                                            if store.audioSelectionID == output.id { ProgressView().controlSize(.small) }
                                            else if output.bluetoothAddress != nil { Text(L("连接")).font(.caption).foregroundStyle(.secondary) }
                                            else if output.selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)) }
                                        })
                                .help(output.name).accessibilityValue(output.selected ? L("当前输出") : "")
                        }
                    }.padding(.horizontal, 8)
                }.frame(height: menuListHeight(count: outputs.count, rowHeight: 44, cap: 220))
            }
            if let error = store.errorMessage { MenuNotice(text: error, error: true) }
            Text(L("切换媒体播放输出；系统提示音仍使用原来的设置。"))
                .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
            SystemMenuFooter(title: L("打开声音设置…"), destination: .sound)
        }
        .onAppear { volumeEdit.sync(sound); if !preview { store.refreshAudioOutputs() } }
        .onChange(of: store.errorMessage) { _, error in
            if error != nil && !volumeEdit.editing { volumeEdit.sync(sound) }
        }
        .onChange(of: sound) { _, _ in if !volumeEdit.editing { volumeEdit.sync(sound) } }
    }
}
