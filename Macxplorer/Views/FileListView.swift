import AppKit
import SwiftUI

struct FileListView: View {
    var model: BrowserModel
    @Binding var rowSelection: Set<URL>
    var actions: ItemActions
    var rename: RenameEditing
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void
    var nameFilter: String = ""
    var onClearFilter: (() -> Void)? = nil
    @Binding var typeAhead: TypeAheadBuffer
    var searchFieldFocused: Bool = false
    @State private var sortOrder = [KeyPathComparator(\FileEntry.name)]
    @State private var hoveredDrop = DropHoverTracker()

    var body: some View {
        FileBrowseChrome(
            model: model,
            nameFilter: nameFilter,
            onClearFilter: onClearFilter,
            receiveDrop: receiveDrop
        ) {
            table
        }
        .focusedSceneValue(\.fileCopyAction, FileCopyAction(urls: copiedURLs))
    }

    private var copiedURLs: [URL] {
        rowSelection.sorted { $0.path < $1.path }
    }

    private var rows: [FileEntry] {
        FileNameFilter.filtered(
            FileListOrder.sorted(model.entries, by: FileSort(order: sortOrder)),
            query: nameFilter
        )
    }

    private var table: some View {
        Table(rows, selection: $rowSelection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { entry in
                rowDrop(for: entry, edge: .leading) { nameCell(entry) }
            }
            .width(min: 180, ideal: 280)

            TableColumn("Date Modified", value: \.modifiedColumn) { entry in
                rowDrop(for: entry, dragFromCell: true, edge: .middle) {
                    plainCell {
                        Text(FileMetadataFormat.dateText(entry.modified))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 140, ideal: 170)

            TableColumn("Size", value: \.sizeColumn) { entry in
                rowDrop(for: entry, dragFromCell: true, edge: .middle) {
                    plainCell(alignment: .trailing) {
                        Text(FileMetadataFormat.sizeText(bytes: entry.size))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Kind", value: \.kind) { entry in
                rowDrop(for: entry, dragFromCell: true, edge: .trailing) {
                    plainCell {
                        Text(entry.kind)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
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
                }
            )
        }
        .onKeyPress(.return) {
            guard rename.session == nil else { return .ignored }
            guard rowSelection.count == 1, let url = rowSelection.first else { return .ignored }
            rename.begin(url)
            return .handled
        }
        .onKeyPress(keys: [.delete, .deleteForward], phases: .down) { press in
            if TrashShortcut.matches(press.modifiers) {
                guard rename.session == nil else { return .ignored }
                guard !rowSelection.isEmpty else { return .ignored }
                actions.moveToTrash(Array(rowSelection))
                return .handled
            }
            return handleTypeAhead(press)
        }
        .onKeyPress(phases: .down) { press in
            handleTypeAhead(press)
        }
        .onDrop(of: [.fileURL], delegate: FileDropDelegate(target: openFolderTarget, receive: receiveDrop))
    }

    private func handleTypeAhead(_ press: KeyPress) -> KeyPress.Result {
        var nextBuffer = typeAhead
        var nextSelection = rowSelection
        let result = FolderTypeAhead.handle(
            press,
            renaming: rename.session != nil,
            searchFocused: searchFieldFocused,
            buffer: &nextBuffer,
            visibleRows: rows,
            selection: &nextSelection
        )
        if result == .handled {
            typeAhead = nextBuffer
            rowSelection = nextSelection
        }
        return result
    }

    private func rowDrop<Content: View>(
        for entry: FileEntry,
        dragFromCell: Bool = false,
        edge: DropTargetHighlight.Edge = .all,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background {
                if DropHover.contains(hoveredDrop.url, folder: entry.url) {
                    DropTargetHighlight(edge: edge)
                }
            }
            .overlay {
                if dragFromCell {
                    FileDragSource(
                        row: entry.url,
                        selection: FileBrowseSelection.dragURLs(for: entry.url, selection: rowSelection),
                        onPrimaryClick: { flags in selectRow(entry.url, flags: flags) }
                    )
                }
            }
            .onDrop(
                of: [.fileURL],
                delegate: FileDropDelegate(
                    target: entry.opensAsFolder ? .folder(entry.url) : .file,
                    receive: receiveDrop,
                    onHover: entry.opensAsFolder ? { hovering in
                        setDropHover(entry.url, hovering: hovering)
                    } : nil,
                    onFinish: clearDropHover
                )
            )
    }

    private func clearDropHover() {
        hoveredDrop = DropHoverTracker()
    }

    private func setDropHover(_ folder: URL, hovering: Bool) {
        if hovering {
            hoveredDrop.enter(folder)
            return
        }
        guard let epoch = hoveredDrop.exit(folder) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            hoveredDrop.clearIfUnchanged(epoch: epoch, folder: folder)
        }
    }

    private var openFolderTarget: DropTargetKind {
        guard let url = model.selectedURL else { return .missing }
        return .folder(url)
    }

    private func selectRow(_ url: URL, flags: NSEvent.ModifierFlags) {
        var next = rowSelection
        FileBrowseSelection.select(url, flags: flags, orderedURLs: rows.map(\.url), selection: &next)
        rowSelection = next
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
                    onDoubleClick: {
                        FileBrowseSelection.open(entry) { url in
                            Task { await model.navigate(to: url) }
                        }
                    },
                    onPrimaryClick: { flags in selectRow(entry.url, flags: flags) },
                    fileDragRow: entry.url,
                    fileDragSelection: FileBrowseSelection.dragURLs(for: entry.url, selection: rowSelection)
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
            moveToTrash: actions.moveToTrash
        )
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
