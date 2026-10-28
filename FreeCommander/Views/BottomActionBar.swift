import SwiftUI

struct BottomActionBar: View {
    @EnvironmentObject private var operations: OperationsEngine
    @EnvironmentObject private var settings: SettingsStore
    let activePane: PaneViewModel
    let onNewFolder: () -> Void
    let onNewFile: () -> Void
    let onDelete: () -> Void

    private var hasSelection: Bool { !activePane.selectedURLs.isEmpty }
    private var canOperate: Bool { hasSelection && !operations.isRunning }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    button("action.copy", icon: "doc.on.doc", enabled: canOperate) {
                        CommandRouter.shared.copy()
                    }
                    button("action.move", icon: "arrow.right.square", enabled: canOperate) {
                        CommandRouter.shared.move()
                    }
                    button("action.newFolder", icon: "folder.badge.plus", enabled: !operations.isRunning, action: onNewFolder)
                    button("action.delete", icon: "trash", enabled: canOperate, action: onDelete)
                    button("action.rename", icon: "pencil", enabled: canOperate) {
                        CommandRouter.shared.rename()
                    }
                }
                divider
                HStack(spacing: 4) {
                    button("action.zip", icon: "doc.zipper", enabled: canOperate) {
                        OperationsEngine.shared.zipSelection(in: activePane)
                    }
                    button("action.preview", icon: "eye", enabled: canOperate) {
                        CommandRouter.shared.preview()
                    }
                    button("action.selectAll", icon: "checkmark.circle", enabled: !activePane.visibleItems.isEmpty && !operations.isRunning) {
                        CommandRouter.shared.selectAll()
                    }
                }
                divider
                hiddenToggleButton
                divider
                Menu {
                    Button(NSLocalizedString("action.newFile", comment: ""), action: onNewFile)
                    Button(NSLocalizedString("action.info", comment: "")) { CommandRouter.shared.info() }
                    Button(NSLocalizedString("menu.toggleHidden", comment: "")) { CommandRouter.shared.toggleHidden() }
                } label: {
                    bottomLabel(icon: "ellipsis.circle", titleKey: "action.more")
                }
                .disabled(operations.isRunning)
                .fixedSize()
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 26)
    }

    /// Szybki przełącznik ukrytych plików (skrót ⌘⇧., jak w Finderze).
    /// Ikona i kolor pokazują stan: wypełnione oko = ukryte pliki widoczne.
    private var hiddenToggleButton: some View {
        Button {
            CommandRouter.shared.toggleHidden()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: settings.showHidden ? "eye.fill" : "eye.slash")
                    .font(.system(size: 14))
                    .foregroundStyle(settings.showHidden ? Color.accentColor : Color.primary)
                    .frame(height: 16)
                Text("action.toggleHidden")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 62)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(operations.isRunning)
        .opacity(operations.isRunning ? 0.35 : 1)
        .help(NSLocalizedString("action.toggleHidden.help", comment: ""))
        .fixedSize()
    }

    private func button(
        _ titleKey: LocalizedStringKey,
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            bottomLabel(icon: icon, titleKey: titleKey)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .fixedSize()
    }

    private func bottomLabel(icon: String, titleKey: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(height: 16)
            Text(titleKey)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 62)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
