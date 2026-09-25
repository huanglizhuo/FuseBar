import SwiftUI

struct SystemMenuHeader<Trailing: View>: View {
    let title: String
    var closesSubmenu = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 4)
            trailing()
            if closesSubmenu {
                Button { SideSubmenu.shared.close(restoreParent: true) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                }.buttonStyle(MenuButtonStyle())
                    .help(L("关闭子菜单")).accessibilityLabel(L("关闭子菜单"))
            }
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct SystemMenuFooter: View {
    let title: String
    let destination: SettingsDestination
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button { destination.open() } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .semibold))
                }.font(.system(size: 12)).padding(10).contentShape(Rectangle())
            }.buttonStyle(MenuButtonStyle()).padding(6)
        }
    }
}

struct DeviceMenuIcon: View {
    let symbol: String
    var selected = false
    var body: some View {
        Image(systemName: symbol).font(.system(size: 15, weight: .medium))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(width: 30, height: 30)
            .background(selected ? Color.accentColor : Color.primary.opacity(0.07), in: Circle())
            .accessibilityHidden(true)
    }
}

struct MenuNotice: View {
    let text: String
    var error = false
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            if error { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange) }
            Text(text).fixedSize(horizontal: false, vertical: true)
        }.font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

/// Circular refresh action shown beside a panel list header.
struct MenuRefreshButton: View {
    let title: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise").frame(width: 24, height: 24)
        }.buttonStyle(MenuButtonStyle())
            .help(title).accessibilityLabel(title)
            .disabled(disabled)
    }
}

/// Standard shape of a selectable row inside a panel list: a leading slot, a
/// flexible title, trailing state, and the shared paddings and hit area.
struct MenuListRow<Leading: View, Title: View, Trailing: View>: View {
    let action: () -> Void
    var selected = false
    var disabled = false
    var verticalPadding: CGFloat = 6
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let title: () -> Title
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leading()
                title()
                Spacer(minLength: 4)
                trailing()
            }.padding(.horizontal, 8).padding(.vertical, verticalPadding).contentShape(Rectangle())
        }.buttonStyle(MenuButtonStyle(selected: selected))
            .disabled(disabled)
    }
}

/// Height for a capped menu list: one row per item, never above `cap`.
func menuListHeight(count: Int, rowHeight: CGFloat, cap: CGFloat) -> CGFloat {
    min(CGFloat(max(1, count)) * rowHeight, cap)
}
