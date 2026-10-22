import SwiftUI

struct BottomActionBar: View {
    @EnvironmentObject private var operations: OperationsEngine
    let activePane: PaneViewModel
    let otherPane: PaneViewModel
    let isDualPane: Bool
    let onNewFolder: () -> Void
    let onNewFile: () -> Void
    let onDelete: () -> Void

    private var hasSelection: Bool { !activePane.selectedURLs.isEmpty }
    private var canOperate: Bool { hasSelection && !operations.isRunning }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                button("action.copy", icon: "doc.on.doc", enabled: canOperate) {
                    operations.copySelection(from: activePane, to: otherPane)
                }
                button("action.move", icon: "arrow.right.doc.on.doc", enabled: canOperate) {
                    operations.moveSelection(from: activePane, to: otherPane)
                }
                button("action.newFolder", icon: "folder.badge.plus", enabled: !operations.isRunning, action: onNewFolder)
                button("action.delete", icon: "trash", enabled: canOperate, role: .destructive, action: onDelete)
                button("action.zip", icon: "doc.zipper", enabled: canOperate) {
                    operations.zipSelection(in: activePane)
                }
                button("action.selectAll", icon: "checkmark.circle", enabled: !activePane.visibleItems.isEmpty && !operations.isRunning) {
                    if activePane.selectedURLs.count >= activePane.visibleItems.count {
                        activePane.clearSelection()
                    } else {
                        activePane.selectAllVisible()
                    }
                }
                Menu {
                    Button(action: onNewFile) {
                        Label("action.newFile", systemImage: "doc.badge.plus")
                    }
                    Button {
                        activePane.showFilter.toggle()
                    } label: {
                        Label("action.filter", systemImage: "magnifyingglass")
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                        Text("action.more")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(width: 64)
                    .padding(.vertical, 6)
                }
                .disabled(operations.isRunning)
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
    }

    private func button(
        _ titleKey: LocalizedStringKey,
        icon: String,
        enabled: Bool,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.title3)
                Text(titleKey)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 64)
            .padding(.vertical, 6)
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}
