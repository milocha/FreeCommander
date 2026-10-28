import AppKit
import SwiftUI

/// Sterowanie kursorem listy plików z poziomu PaneViewModel
/// (Space/Insert z KeyboardMonitor trafiają tutaj przez mostek).
@MainActor
protocol PaneListController: AnyObject {
    /// Przełącz zaznaczenie elementu pod kursorem i przesuń kursor w dół (TC).
    func toggleMarkUnderCursorAndAdvance()
}

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
        nameColumn.width = Coordinator.storedWidth(for: "name", fallback: 440)
        nameColumn.minWidth = 120
        // Dopasowaniem kolumn do szerokości panelu zajmuje się fitColumns(_:);
        // autoresizing AppKit fightowałby z nim przy zmianie rozmiaru okna.
        nameColumn.resizingMask = .userResizingMask
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(
            key: "name", ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = NSLocalizedString("col.size", comment: "")
        sizeColumn.width = Coordinator.storedWidth(for: "size", fallback: 90)
        sizeColumn.minWidth = 60
        sizeColumn.maxWidth = 220
        sizeColumn.resizingMask = .userResizingMask
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: true)
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = NSLocalizedString("col.date", comment: "")
        dateColumn.width = Coordinator.storedWidth(for: "date", fallback: 150)
        dateColumn.minWidth = 90
        dateColumn.maxWidth = 320
        dateColumn.resizingMask = .userResizingMask
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
        // Bezpiecznik dla ekstremalnie wąskich paneli (poniżej sumy minimów
        // kolumn): wtedy kolumny można dosięgnąć przewijaniem poziomym
        // (shift + kółko myszy / dwa palce poziomo na trackpadzie).
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        context.coordinator.table = table
        context.coordinator.clipView = scrollView.contentView
        pane.listController = context.coordinator
        context.coordinator.installResizeObserver()
        context.coordinator.sync()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.sync()
        context.coordinator.fitColumns(to: scrollView.contentView.bounds.width)
    }

    // MARK: - Koordynator

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, PaneListController {
        private let pane: PaneViewModel
        private let onActivate: () -> Void
        private let onOpen: (FileItem) -> Void

        var table: NSTableView?
        var clipView: NSClipView?
        /// Wiersz pod kursorem TC (niezależny od zestawu zaznaczeń).
        var cursorRow: Int = -1
        private var lastItems: [FileItem] = []
        private var syncingSelection = false
        private var pendingMenuItem: FileItem?
        private var resizeObserver: NSObjectProtocol?
        private var frameObserver: NSObjectProtocol?
        private var widthSaveTask: DispatchWorkItem?

        init(pane: PaneViewModel, onActivate: @escaping () -> Void, onOpen: @escaping (FileItem) -> Void) {
            self.pane = pane
            self.onActivate = onActivate
            self.onOpen = onOpen
        }

        deinit {
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
            }
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
        }

        // MARK: Szerokości kolumn (zmieniane dragiem, zapamiętywane globalnie)

        static func storedWidth(for columnKey: String, fallback: CGFloat) -> CGFloat {
            let value = UserDefaults.standard.double(forKey: "col.\(columnKey).width")
            return value > 0 ? CGFloat(value) : fallback
        }

        func installResizeObserver() {
            guard let table, resizeObserver == nil else { return }
            // Drag użytkownika: kolumny mają dalej wypełniać panel (jak w Finderze),
            // ale kolumna trzymana kursorem nie może być cofana przez dopasowanie.
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSTableView.columnDidResizeNotification,
                object: table,
                queue: .main) { [weak self] notification in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        let dragged = notification.userInfo?["NSTableColumn"] as? NSTableColumn
                        self.fitColumns(to: self.clipView?.bounds.width ?? 0, protecting: dragged)
                        self.scheduleColumnWidthSave()
                    }
                }
            // Zmiana szerokości panelu (resize okna, sidebary, scroller pionowy).
            if let clipView, frameObserver == nil {
                clipView.postsFrameChangedNotifications = true
                frameObserver = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: clipView,
                    queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.fitColumns(to: self?.clipView?.bounds.width ?? 0)
                        }
                    }
            }
        }

        /// Dopasowanie kolumn do widocznej szerokości panelu w duchu TC/Findera:
        /// nadmiar (szersze kolumny niż panel) zwijany jest proporcjonalnie do
        /// minimów kolumn, a luz rozciąga kolumnę nazwy. Kolumna przeciągana
        /// właśnie kursorem (`protecting`) nie jest cofana. Poniżej sumy minimów
        /// zostaje przewijanie poziome — nic nie jest ucinane bez dostępu.
        func fitColumns(to available: CGFloat, protecting protected: NSTableColumn? = nil) {
            guard let table, available > 0, table.tableColumns.count > 1 else { return }
            let columns = table.tableColumns
            var widths = columns.map(\.width)
            let mins = columns.map(\.minWidth)
            let total = widths.reduce(0, +)
            if total < available {
                widths[0] += available - total
            } else if total > available {
                var shrinkable: CGFloat = 0
                for index in widths.indices where columns[index] !== protected {
                    shrinkable += max(widths[index] - mins[index], 0)
                }
                guard shrinkable > 0 else { return }
                let excess = min(total - available, shrinkable)
                for index in widths.indices where columns[index] !== protected {
                    let room = max(widths[index] - mins[index], 0)
                    widths[index] -= excess * room / shrinkable
                }
            }
            for (index, column) in columns.enumerated() where column !== protected {
                let target = max(widths[index], column.minWidth)
                if abs(column.width - target) > 0.5 {
                    column.width = target
                }
            }
        }

        private func scheduleColumnWidthSave() {
            widthSaveTask?.cancel()
            let task = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    self?.saveColumnWidths()
                }
            }
            widthSaveTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
        }

        private func saveColumnWidths() {
            guard let table else { return }
            for column in table.tableColumns {
                guard let key = column.identifier.rawValue as String? else { continue }
                UserDefaults.standard.set(Double(column.width), forKey: "col.\(key).width")
            }
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
            // Kursor TC: ostatnio kliknięty wiersz, po strzałce — bieżący wiersz.
            if table.clickedRow >= 0 {
                cursorRow = table.clickedRow
            } else if table.selectedRow >= 0 {
                cursorRow = table.selectedRow
            }
            pane.cursorURL = (cursorRow >= 0 && cursorRow < items.count) ? items[cursorRow].url : nil
            onActivate()
        }

        // MARK: Kursor TC (Space / Insert)

        /// Space/Insert w standardzie TC: przełącz zaznaczenie wiersza pod kursorem
        /// bez ruszania pozostałych zaznaczeń, potem kursor o wiersz w dół.
        func toggleMarkUnderCursorAndAdvance() {
            guard let table else { return }
            let items = pane.visibleItems
            guard cursorRow >= 0, cursorRow < items.count else { return }
            let item = items[cursorRow]
            syncingSelection = true
            if pane.selectedURLs.contains(item.url) {
                pane.selectedURLs.remove(item.url)
                table.deselectRow(cursorRow)
            } else {
                pane.selectedURLs.insert(item.url)
                table.selectRowIndexes(IndexSet(integer: cursorRow), byExtendingSelection: true)
            }
            syncingSelection = false
            let next = min(cursorRow + 1, items.count - 1)
            cursorRow = next
            pane.cursorURL = items[next].url
            table.scrollRowToVisible(next)
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
            menu.addItem(
                withTitle: NSLocalizedString("action.copyPath", comment: ""),
                action: #selector(menuCopyPath), keyEquivalent: "").target = self
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
        @objc private func menuCopyPath() {
            let targets = pane.selectedItems().isEmpty ? [pendingMenuItem].compactMap { $0 } : pane.selectedItems()
            pane.copyPaths(of: targets)
        }
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
