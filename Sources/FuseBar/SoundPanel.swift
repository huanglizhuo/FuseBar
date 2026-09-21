import SwiftUI

struct SoundPanel: View {
    @ObservedObject var store: StatusStore
    var preview = false
    var isSubmenu = false
    @State private var volume = 0.0
    @State private var editing = false
    @State private var volumeDeviceUID: String?

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
                    Text(sound.volume == nil ? "—" : "\(Int((volume * 100).rounded()))%")
                        .monospacedDigit().foregroundStyle(.secondary)
                }.font(.system(size: 12))
                HStack(spacing: 8) {
                    Button { store.setMuted(sound.muted != true) } label: {
                        Image(systemName: sound.muted == true ? "speaker.slash.fill" : "speaker.fill")
                            .frame(width: 26, height: 26)
                    }.buttonStyle(MenuButtonStyle(selected: sound.muted == true))
                        .disabled(store.audioBusy || !sound.canSetMute)
                        .help(L("静音")).accessibilityLabel(L("静音"))
                        .accessibilityValue(sound.muted == true ? L("已开启") : L("已关闭"))
                    Slider(value: Binding(get: { volume }, set: { value in
                        guard volumeDeviceUID == sound.deviceUID else { return }
                        volume = value
                        store.setVolume(value)
                    }), in: 0...1, onEditingChanged: { value in
                        editing = value
                        if !value && (volumeDeviceUID != sound.deviceUID || store.errorMessage != nil) { syncVolume() }
                    })
                    .disabled(store.audioBusy || !sound.canSetVolume)
                    .accessibilityLabel(L("输出音量"))
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                }
                if sound.muted == true {
                    Text(L("系统静音已开启；调整音量不会自动取消静音。"))
                        .font(.caption2).foregroundStyle(.secondary)
                } else if sound.available && !sound.canSetVolume {
                    Text(L("此设备由硬件控制音量。")).font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
            Divider().padding(.horizontal, 16)
            HStack {
                Text(L("输出设备")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { store.refreshAudioOutputs() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 24, height: 24)
                }.buttonStyle(MenuButtonStyle()).help(L("刷新")).accessibilityLabel(L("刷新"))
                    .disabled(store.audioBusy)
            }.padding(.horizontal, 16).padding(.top, 6)
            if outputs.isEmpty {
                MenuNotice(text: store.audioBusy ? L("正在读取设备…") : L("没有可用的输出设备。请检查连接，或打开声音设置。"))
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(outputs) { output in
                            Button { if !output.selected { store.selectAudioOutput(output) } } label: {
                                HStack(spacing: 10) {
                                    DeviceMenuIcon(symbol: output.symbol, selected: output.selected)
                                    Text(output.name).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 4)
                                    if store.audioSelectionID == output.id { ProgressView().controlSize(.small) }
                                    else if output.bluetoothAddress != nil { Text(L("连接")).font(.caption).foregroundStyle(.secondary) }
                                    else if output.selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)) }
                                }.padding(.horizontal, 8).padding(.vertical, 6).contentShape(Rectangle())
                            }.buttonStyle(MenuButtonStyle(selected: output.selected))
                                .disabled(store.audioBusy || editing)
                                .help(output.name).accessibilityValue(output.selected ? L("当前输出") : "")
                        }
                    }.padding(.horizontal, 8)
                }.frame(height: min(CGFloat(outputs.count) * 44, 220))
            }
            if let error = store.errorMessage { MenuNotice(text: error, error: true) }
            Text(L("切换媒体播放输出；系统提示音仍使用原来的设置。"))
                .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
            SystemMenuFooter(title: L("打开声音设置…"), destination: .sound)
        }
        .onAppear { syncVolume(); if !preview { store.refreshAudioOutputs() } }
        .onChange(of: store.errorMessage) { _, error in
            if error != nil && !editing { syncVolume() }
        }
        .onChange(of: sound) { _, _ in if !editing { syncVolume() } }
    }

    private func syncVolume() {
        volume = Double(sound.volume ?? 0)
        volumeDeviceUID = sound.deviceUID
    }
}
