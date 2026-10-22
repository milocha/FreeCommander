import SwiftUI

struct BottomActionBar: View {
    @EnvironmentObject private var operations: OperationsEngine
    let activePane: PaneViewModel
    let onNewFolder: () -> Void
    let onNewFile: () -> Void
    let onDelete: () -> Void

    private var hasSelection: Bool { !activePane.selectedURLs.isEmpty }
    private var canOperate: Bool { hasSelection && !operations.isRunning }

    var body: some View {
        HStack(spacing: 4) {
            button("action.copy", icon: "doc.on.doc", enabled: canOperate) {
                CommandRouter.shared.copy()
            }
            button("action.move", icon: "arrow.right.doc.on.doc", enabled: canOperate) {
                CommandRouter.shared.move()
            }
            button("action.newFolder", icon: "folder.badge.plus", enabled: !operations.isRunning, action: onNewFolder)
            button("action.delete", icon: "trash", enabled: canOperate, action: onDelete)
            button("action.rename", icon: "pencil", enabled: canOperate) {
                CommandRouter.shared.rename()
            }
            button("action.zip", icon: "doc.zipper", enabled: canOperate) {
                OperationsEngine.shared.zipSelection(in: activePane)
            }
            button("action.preview", icon: "eye", enabled: canOperate) {
                CommandRouter.shared.preview()
            }
            button("action.selectAll", icon: "checkmark.circle", enabled: !activePane.visibleItems.isEmpty && !operations.isRunning) {
                CommandRouter.shared.selectAll()
            }
            Menu {
                Button(NSLocalizedString("action.newFile", comment: ""), action: onNewFile)
                Button(NSLocalizedString("action.info", comment: "")) { CommandRouter.shared.info() }
                Button(NSLocalizedString("menu.toggleHidden", comment: "")) { CommandRouter.shared.toggleHidden() }
            } label: {
                bottomLabel(icon: "ellipsis.circle", titleKey: "action.more")
            }
            .disabled(operations.isRunning)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .underPageBackgroundColor))
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
    }

    private func bottomLabel(icon: String, titleKey: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(titleKey)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 60)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
