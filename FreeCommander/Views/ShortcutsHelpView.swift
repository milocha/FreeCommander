import SwiftUI

/// Okno pomocy: spis skrótów w standardzie Total Commandera oraz macOS.
/// Otwierane z menu Pomoc, skrótem ⌘? oraz klawiszem F1 (jak w TC).
struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private struct HelpRow: Identifiable {
        let id = UUID()
        let keys: String
        let label: LocalizedStringKey
    }

    private struct HelpSection: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let rows: [HelpRow]
    }

    private var sections: [HelpSection] {
        [
            HelpSection(title: "help.section.tcNav", rows: [
                HelpRow(keys: "Enter", label: "help.openUnderCursor"),
                HelpRow(keys: "Backspace · Ctrl+PgUp", label: "help.parentDir"),
                HelpRow(keys: "Ctrl+PgDn", label: "help.openUnderCursor"),
                HelpRow(keys: "Tab", label: "help.switchPane"),
            ]),
            HelpSection(title: "help.section.tcSel", rows: [
                HelpRow(keys: "Space · Insert", label: "help.markCursor"),
                HelpRow(keys: "Gray+ · Gray−", label: "help.groupPattern"),
                HelpRow(keys: "⌘A", label: "action.selectAll"),
            ]),
            HelpSection(title: "help.section.tcOps", rows: [
                HelpRow(keys: "F2", label: "action.refresh"),
                HelpRow(keys: "F3 · Ctrl+Q", label: "action.preview"),
                HelpRow(keys: "F4", label: "help.editFile"),
                HelpRow(keys: "F5", label: "action.copy"),
                HelpRow(keys: "F6", label: "action.move"),
                HelpRow(keys: "Shift+F6", label: "action.rename"),
                HelpRow(keys: "F7", label: "action.newFolder"),
                HelpRow(keys: "F8 · Delete", label: "action.delete"),
                HelpRow(keys: "Alt+F5 · Alt+F6", label: "help.zipUnzip"),
                HelpRow(keys: "Alt+Enter", label: "help.properties"),
            ]),
            HelpSection(title: "help.section.mac", rows: [
                HelpRow(keys: "⌘C · ⌘X · ⌘V", label: "help.clipboardFiles"),
                HelpRow(keys: "⌘⌥C", label: "action.copyPath"),
                HelpRow(keys: "⌘⌫", label: "action.trash"),
                HelpRow(keys: "⌘I · Alt+Enter", label: "action.info"),
                HelpRow(keys: "⌘⇧N", label: "action.newFolder"),
                HelpRow(keys: "⌘O · ⌘↓", label: "action.open"),
                HelpRow(keys: "⌘↑", label: "help.parentDir"),
                HelpRow(keys: "⌘1 · ⌘2", label: "help.panel1_2"),
                HelpRow(keys: "⌘F", label: "action.filter"),
                HelpRow(keys: "⌘R · F2", label: "action.refresh"),
                HelpRow(keys: "⌘⇧.", label: "menu.toggleHidden"),
            ]),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(section.title)
                                .font(.headline)
                            ForEach(section.rows) { row in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.keys)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 168, alignment: .leading)
                                    Text(row.label)
                                        .font(.callout)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 640, height: 580)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text("help.title")
                .font(.title2.bold())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            Text("help.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("common.close") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
