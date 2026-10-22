import AppKit
import SwiftUI

/// Natywna tabela plików (NSTableView): wielokrotne zaznaczanie z cmd/shift,
/// dwuklik otwiera, kliknięcie nagłówka sortuje, strzałki przechodzą po liście.
struct FileListView: NSViewRepresentable {
    @ObservedObject var pane: PaneViewModel
    let onActivate: () -> Void
    let onOpen: (FileItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(pane: pane, onActivate: onActivate, onOpen: onOpen)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.headerView = NSTableHeaderView()
        table.rowHeight = 22
        table.usesAlternatingRowBackgroundColors = false
        table.gridStyleMask = [.solidVerticalGridLineMask]
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnReordering = false
        table.style = .fullWidth

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = NSLocalizedString("col.name", comment: "")
        nameColumn.width = 440
        nameColumn.minWidth = 160
        nameColumn.resizingMask = .autoresizingMask
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(
            key: "name", ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = NSLocalizedString("col.size", comment: "")
        sizeColumn.width = 90
        sizeColumn.minWidth = 70
        sizeColumn.maxWidth = 140
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: true)
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = NSLocalizedString("col.date", comment: "")
        dateColumn.width = 150
        dateColumn.minWidth = 110
        dateColumn.maxWidth = 200
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(key: "date", ascending: true)
        table.addTableColumn(nameColumn)
        table.addTableColumn(sizeColumn)
        table.addTableColumn(dateColumn)

        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.doubleClicked(_:))

        let menu = NSMenu()
        menu.delegate = context.coordinator
        table.menu = menu

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        context.coordinator.table = table
        context.coordinator.sync()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.sync()
    }

    // MARK: - Koordynator

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        private let pane: PaneViewModel
        private let onActivate: () -> Void
        private let onOpen: (FileItem) -> Void

        var table: NSTableView?
        private var lastItems: [FileItem] = []
        private var syncingSelection = false
        private var pendingMenuItem: FileItem?

        init(pane: PaneViewModel, onActivate: @escaping () -> Void, onOpen: @escaping (FileItem) -> Void) {
            self.pane = pane
            self.onActivate = onActivate
            self.onOpen = onOpen
        }

        // MARK: Dane

        func numberOfRows(in tableView: NSTableView) -> Int {
            pane.visibleItems.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let items = pane.visibleItems
            guard row < items.count, let column = tableColumn else { return nil }
            let item = items[row]
            let cell = NSTableCellView()

            switch column.identifier.rawValue {
            case "name":
                let icon = NSImageView()
                icon.image = NSWorkspace.shared.icon(forFile: item.url.path(percentEncoded: false))
                icon.image?.size = NSSize(width: 16, height: 16)
                icon.translatesAutoresizingMaskIntoConstraints = false
                let label = NSTextField(labelWithString: item.name)
                label.lineBreakMode = .byTruncatingMiddle
                label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
                label.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(icon)
                cell.addSubview(label)
                NSLayoutConstraint.activate([
                    icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 16),
                    icon.heightAnchor.constraint(equalToConstant: 16),
                    label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            case "size":
                let text: String
                if item.isDirectory {
                    text = "<\(NSLocalizedString("dir.marker", comment: ""))>"
                } else {
                    text = Formatters.size(item.size ?? 0)
                }
                let label = rightAlignedLabel(text)
                cell.addSubview(label)
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            case "date":
                let label = rightAlignedLabel(item.modificationDate.map(Formatters.date) ?? "")
                cell.addSubview(label)
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            default:
                break
            }
            return cell
        }

        private func rightAlignedLabel(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.alignment = .right
            label.lineBreakMode = .byTruncatingHead
            label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }

        // MARK: Zaznaczenie i akcje

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !syncingSelection, let table = notification.object as? NSTableView else { return }
            let items = pane.visibleItems
            let selected = Set(table.selectedRowIndexes.compactMap { row -> URL? in
                guard row >= 0, row < items.count else { return nil }
                return items[row].url
            })
            pane.selectedURLs = selected
            onActivate()
        }

        @objc func doubleClicked(_ sender: Any?) {
            let row = table?.clickedRow ?? -1
            let items = pane.visibleItems
            guard row >= 0, row < items.count else { return }
            onOpen(items[row])
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first,
                  let field = SortField.fromSortKey(descriptor.key ?? "") else { return }
            pane.sortField = field
            pane.sortDirection = descriptor.ascending ? .ascending : .descending
        }

        // MARK: Menu kontekstowe

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            let row = table?.clickedRow ?? -1
            let items = pane.visibleItems
            guard row >= 0, row < items.count else {
                let selectAll = menu.addItem(
                    withTitle: NSLocalizedString("action.selectAll", comment: ""),
                    action: #selector(menuSelectAll),
                    keyEquivalent: "")
                selectAll.target = self
                return
            }
            // Kliknięcie poza zaznaczeniem zaznacza kliknięty wiersz (zachowanie Findera).
            if !(table?.selectedRowIndexes.contains(row) ?? false) {
                table?.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
            let item = items[row]
            pendingMenuItem = item

            menu.addItem(
                withTitle: item.isDirectory
                    ? NSLocalizedString("action.openFolder", comment: "")
                    : NSLocalizedString("action.open", comment: ""),
                action: #selector(menuOpen), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.preview", comment: ""),
                action: #selector(menuPreview), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.revealInFinder", comment: ""),
                action: #selector(menuReveal), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(
                withTitle: NSLocalizedString("action.copyToOther", comment: ""),
                action: #selector(menuCopy), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.moveToOther", comment: ""),
                action: #selector(menuMove), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(
                withTitle: NSLocalizedString("action.rename", comment: ""),
                action: #selector(menuRename), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.duplicate", comment: ""),
                action: #selector(menuDuplicate), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.info", comment: ""),
                action: #selector(menuInfo), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.zipSelection", comment: ""),
                action: #selector(menuZip), keyEquivalent: "").target = self
            if item.isArchive {
                menu.addItem(
                    withTitle: NSLocalizedString("action.unzip", comment: ""),
                    action: #selector(menuUnzip), keyEquivalent: "").target = self
            }
            menu.addItem(.separator())
            menu.addItem(
                withTitle: NSLocalizedString("action.trash", comment: ""),
                action: #selector(menuTrash), keyEquivalent: "").target = self
            menu.addItem(
                withTitle: NSLocalizedString("action.deletePermanent", comment: ""),
                action: #selector(menuDeletePermanent), keyEquivalent: "").target = self
        }

        private var operations: OperationsEngine { OperationsEngine.shared }

        @objc private func menuOpen() { guard let item = pendingMenuItem else { return }; onOpen(item) }
        @objc private func menuPreview() { guard let item = pendingMenuItem else { return }; pane.requestPreview(item) }
        @objc private func menuReveal() { guard let item = pendingMenuItem else { return }; pane.revealInFinder(item) }
        @objc private func menuCopy() { operations.copySelection(from: pane, to: otherPane()) }
        @objc private func menuMove() { operations.moveSelection(from: pane, to: otherPane()) }
        @objc private func menuRename() { guard let item = pendingMenuItem else { return }; pane.renameItem = item }
        @objc private func menuDuplicate() { guard let item = pendingMenuItem else { return }; pane.duplicate(item) }
        @objc private func menuInfo() { guard let item = pendingMenuItem else { return }; pane.infoItem = item }
        @objc private func menuZip() { operations.zipSelection(in: pane) }
        @objc private func menuUnzip() { guard let item = pendingMenuItem, item.isArchive else { return }; operations.unzip(item, in: pane) }
        @objc private func menuTrash() { pane.deleteRequest = pane.selectedItems().first ?? pendingMenuItem }
        @objc private func menuDeletePermanent() { pane.deleteRequest = pane.selectedItems().first ?? pendingMenuItem }
        @objc private func menuSelectAll() { pane.selectAllVisible() }

        /// Panel po drugiej stronie okna — potrzebny menu Copy/Move.
        private func otherPane() -> PaneViewModel {
            CommandRouter.shared.otherPaneProvider(pane)
        }

        // MARK: Synchronizacja stanu SwiftUI -> AppKit

        func sync() {
            guard let table else { return }
            let items = pane.visibleItems
            if items != lastItems {
                lastItems = items
                table.reloadData()
            }
            let sortKey = pane.sortField.sortKey
            if table.sortDescriptors.first?.key != sortKey
                || table.sortDescriptors.first?.ascending != (pane.sortDirection == .ascending) {
                let descriptor: NSSortDescriptor
                if sortKey == "name" {
                    descriptor = NSSortDescriptor(
                        key: "name", ascending: pane.sortDirection == .ascending,
                        selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
                } else {
                    descriptor = NSSortDescriptor(key: sortKey, ascending: pane.sortDirection == .ascending)
                }
                table.sortDescriptors = [descriptor]
            }
            let selectedIndexes = IndexSet(items.enumerated().compactMap { index, item in
                pane.selectedURLs.contains(item.url) ? index : nil
            })
            if table.selectedRowIndexes != selectedIndexes {
                syncingSelection = true
                table.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
                syncingSelection = false
            }
        }
    }
}
