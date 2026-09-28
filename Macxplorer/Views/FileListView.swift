import AppKit
import SwiftUI

struct FileListView: View {
    var model: BrowserModel
    @Binding var rowSelection: Set<URL>
    var actions: ItemActions
    var rename: RenameEditing
    @State private var sortOrder = [KeyPathComparator(\FileEntry.name)]

    var body: some View {
        Group {
            if model.isLoadingDetail, model.entries.isEmpty, model.detailError == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detailError = model.detailError, model.entries.isEmpty {
                ContentUnavailableView(
                    "Can't Open Folder",
                    systemImage: "exclamationmark.triangle",
                    description: Text(detailError)
                )
            } else if model.entries.isEmpty {
                ContentUnavailableView(
                    "Empty Folder",
                    systemImage: "folder",
                    description: Text("This folder is empty.")
                )
            } else {
                table
            }
        }
    }

    private var rows: [FileEntry] {
        FileListOrder.sorted(model.entries, by: FileSort(order: sortOrder))
    }

    private var table: some View {
        Table(rows, selection: $rowSelection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { entry in
                nameCell(entry)
            }
            .width(min: 180, ideal: 280)

            TableColumn("Date Modified", value: \.modifiedColumn) { entry in
                plainCell {
                    Text(FileMetadataFormat.dateText(entry.modified))
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 140, ideal: 170)

            TableColumn("Size", value: \.sizeColumn) { entry in
                plainCell(alignment: .trailing) {
                    Text(FileMetadataFormat.sizeText(bytes: entry.size))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Kind", value: \.kind) { entry in
                plainCell {
                    Text(entry.kind)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 100, ideal: 140)
        }
        .contextMenu(forSelectionType: URL.self) { selection in
            ItemContextMenu(
                urls: Array(selection),
                opensAsFolder: { url in
                    model.entries.first { $0.url == url }?.opensAsFolder == true
                },
                actions: listActions,
                favorite: model.favoriteMenuAction(for: Array(selection)).map {
                    FavoriteMenuItem(action: $0, perform: model.applyFavorites)
                },
                canCreateFolder: model.selectedURL != nil
            )
        }
        .onKeyPress(.return) {
            guard rename.session == nil else { return .ignored }
            guard rowSelection.count == 1, let url = rowSelection.first else { return .ignored }
            rename.begin(url)
            return .handled
        }
        .onKeyPress(keys: [.delete, .deleteForward], phases: .down) { press in
            guard rename.session == nil, TrashShortcut.matches(press.modifiers) else { return .ignored }
            guard !rowSelection.isEmpty else { return .ignored }
            actions.moveToTrash(Array(rowSelection))
            return .handled
        }
    }

    private func nameCell(_ entry: FileEntry) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: IconStore.shared.image(for: entry.url, isDirectory: entry.opensAsFolder))
                .resizable()
                .frame(width: 16, height: 16)
            if isRenaming(entry.url) {
                InlineRenameField(
                    draft: rename.draft,
                    isFolder: rename.session?.isFolder == true,
                    refocusID: rename.refocusID,
                    onCommit: rename.commit,
                    onCancel: rename.cancel
                )
            } else {
                Text(entry.name)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if !isRenaming(entry.url) {
                RenameClickCatcher(
                    isSelected: rowSelection.contains(entry.url),
                    onSlowClick: { rename.begin(entry.url) },
                    onDoubleClick: { open(entry) }
                )
            }
        }
    }

    private func isRenaming(_ url: URL) -> Bool {
        guard let session = rename.session else { return false }
        return Favorites.key(for: session.url) == Favorites.key(for: url)
    }

    private func plainCell<Content: View>(
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var listActions: ItemActions {
        ItemActions(
            revealInFinder: actions.revealInFinder,
            openInTerminal: actions.openInTerminal,
            quickLook: { url in
                rowSelection = [url]
                actions.quickLook(url)
            },
            rename: actions.rename,
            moveToTrash: actions.moveToTrash,
            newFolder: actions.newFolder
        )
    }

    private func open(_ entry: FileEntry) {
        if let folder = FolderOpenTarget.url(for: entry.url, opensAsFolder: entry.opensAsFolder) {
            Task { await model.navigate(to: folder) }
        } else {
            NSWorkspace.shared.open(entry.url)
        }
    }
}

@MainActor
enum FileMetadataFormat {
    static func dateText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func sizeText(bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return byteCount.string(fromByteCount: bytes)
    }

    private static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}
