import AppKit
import SwiftUI

struct ColumnBrowserView: View {
    var model: BrowserModel
    @Binding var rowSelection: Set<URL>
    var actions: ItemActions
    var rename: RenameEditing
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void
    var nameFilter: String = ""
    var onClearFilter: (() -> Void)? = nil
    @Binding var typeAhead: TypeAheadBuffer
    var searchFieldFocused: Bool = false

    @State private var columnFolders: [URL] = []
    @State private var columnEntries: [String: [FileEntry]] = [:]
    @State private var loadGeneration = 0
    @State private var hoveredDrop = DropHoverTracker()

    private let columnWidth: CGFloat = 220

    var body: some View {
        Group {
            if model.selectedURL == nil {
                ContentUnavailableView(
                    "No Folder",
                    systemImage: "folder",
                    description: Text("Select a folder in the sidebar.")
                )
            } else if columnFolders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                columnsScroll
            }
        }
        .focusedSceneValue(\.fileCopyAction, FileCopyAction(urls: copiedURLs))
        .task(id: model.selectedURL.map { Favorites.key(for: $0) }) {
            await syncColumnsFromSelection()
        }
        .onChange(of: model.entries) { _, _ in
            syncLastColumnFromModel()
        }
        .onChange(of: model.showHiddenInList) { _, _ in
            Task { await reloadAncestorColumns() }
        }
    }

    private var copiedURLs: [URL] {
        rowSelection.sorted { $0.path < $1.path }
    }

    private var roots: [URL] {
        model.roots.map(\.url)
    }

    private var columnsScroll: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(columnFolders.enumerated()), id: \.offset) { index, folder in
                    columnView(index: index, folder: folder)
                    if index < columnFolders.count - 1 {
                        Divider()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Color(nsColor: .textBackgroundColor))
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
            visibleRows: lastColumnRows,
            selection: &nextSelection
        )
        if result == .handled {
            typeAhead = nextBuffer
            rowSelection = nextSelection
        }
        return result
    }

    private var lastColumnRows: [FileEntry] {
        guard let folder = columnFolders.last else { return [] }
        return entries(for: folder)
    }

    private func columnView(index: Int, folder: URL) -> some View {
        let rows = entries(for: folder)
        let highlight = highlightedURL(in: index)
        let unfilteredLast = isLastColumn(index)
            ? (columnEntries[Favorites.key(for: folder)] ?? [])
            : []
        let noMatches = isLastColumn(index)
            && !unfilteredLast.isEmpty
            && rows.isEmpty
            && !nameFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if rows.isEmpty, isLastColumn(index), model.isLoadingDetail {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if rows.isEmpty, isLastColumn(index), let detailError = model.detailError {
                    Text(detailError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if noMatches {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No Matches")
                            .font(.headline)
                        Text("No items match “\(nameFilter.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let onClearFilter {
                            Button("Clear Search", action: onClearFilter)
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding()
                } else {
                    ForEach(rows) { entry in
                        columnRow(entry, index: index, highlight: highlight)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: columnWidth)
        .frame(maxHeight: .infinity)
        .onDrop(
            of: [.fileURL],
            delegate: FileDropDelegate(target: .folder(folder), receive: receiveDrop)
        )
    }

    private func columnRow(_ entry: FileEntry, index: Int, highlight: URL?) -> some View {
        let selected = isRowSelected(entry, highlight: highlight)
        return HStack(spacing: 6) {
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
                Spacer(minLength: 0)
                if entry.opensAsFolder {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.clear)
                .padding(.horizontal, 4)
        }
        .background {
            if DropHover.contains(hoveredDrop.url, folder: entry.url) {
                DropTargetHighlight(edge: .all)
            }
        }
        .overlay {
            if !isRenaming(entry.url) {
                RenameClickCatcher(
                    isSelected: selected,
                    onSlowClick: { rename.begin(entry.url) },
                    onDoubleClick: {
                        if entry.opensAsFolder {
                            selectFolder(entry.url, at: index)
                        } else {
                            FileBrowseSelection.open(entry) { url in
                                Task { await model.navigate(to: url) }
                            }
                        }
                    },
                    onPrimaryClick: { flags in
                        handleClick(entry, at: index, flags: flags)
                    },
                    fileDragRow: entry.url,
                    fileDragSelection: FileBrowseSelection.dragURLs(for: entry.url, selection: dragSelection(for: entry))
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
        .contextMenu {
            ItemContextMenu(
                urls: contextURLs(for: entry.url),
                opensAsFolder: { url in
                    entryLookup(url)?.opensAsFolder == true
                },
                actions: listActions,
                favorite: model.favoriteMenuAction(for: contextURLs(for: entry.url)).map {
                    FavoriteMenuItem(action: $0, perform: model.applyFavorites)
                }
            )
        }
    }

    private func handleClick(_ entry: FileEntry, at index: Int, flags: NSEvent.ModifierFlags) {
        if flags.contains(.command) || flags.contains(.shift) {
            let ordered = entries(for: columnFolders[index]).map(\.url)
            var next = rowSelection
            FileBrowseSelection.select(entry.url, flags: flags, orderedURLs: ordered, selection: &next)
            rowSelection = next
            return
        }
        if entry.opensAsFolder {
            selectFolder(entry.url, at: index)
        } else {
            selectFile(entry.url, at: index)
        }
    }

    private func selectFolder(_ url: URL, at index: Int) {
        rowSelection = [url]
        columnFolders = ColumnPath.selectingFolder(url, in: columnFolders, at: index)
        Task { await model.navigate(to: url) }
    }

    private func selectFile(_ url: URL, at index: Int) {
        rowSelection = [url]
        columnFolders = ColumnPath.selectingFile(in: columnFolders, at: index)
        // Keep BrowserModel on the file's parent (this column's folder).
        let folder = columnFolders[index]
        if let selected = model.selectedURL, Favorites.key(for: selected) != Favorites.key(for: folder) {
            Task { await model.navigate(to: folder) }
        }
    }

    private func syncColumnsFromSelection() async {
        guard let selected = model.selectedURL else {
            columnFolders = []
            columnEntries = [:]
            return
        }
        let nextFolders = ColumnPath.folders(to: selected, roots: roots)
        columnFolders = nextFolders
        syncLastColumnFromModel()
        await reloadAncestorColumns()
    }

    private func syncLastColumnFromModel() {
        guard let selected = model.selectedURL else { return }
        columnEntries[Favorites.key(for: selected)] = FileListOrder.sorted(model.entries)
    }

    private func reloadAncestorColumns() async {
        loadGeneration += 1
        let ticket = loadGeneration
        let folders = columnFolders
        let showHidden = model.showHiddenInList
        let lastKey = folders.last.map { Favorites.key(for: $0) }
        for folder in folders {
            if Task.isCancelled || ticket != loadGeneration { return }
            let key = Favorites.key(for: folder)
            if key == lastKey {
                continue
            }
            do {
                let listed = try await FileSystemService.listDirectory(at: folder, showHidden: showHidden)
                if ticket != loadGeneration { return }
                columnEntries[key] = FileListOrder.sorted(listed)
            } catch {
                if ticket != loadGeneration { return }
                columnEntries[key] = []
            }
        }
    }

    private func entries(for folder: URL) -> [FileEntry] {
        let listed = columnEntries[Favorites.key(for: folder)] ?? []
        guard isLastColumnFolder(folder) else { return listed }
        return FileNameFilter.filtered(listed, query: nameFilter)
    }

    private func isLastColumnFolder(_ folder: URL) -> Bool {
        guard let last = columnFolders.last else { return false }
        return Favorites.key(for: last) == Favorites.key(for: folder)
    }

    private func highlightedURL(in index: Int) -> URL? {
        if index + 1 < columnFolders.count {
            return columnFolders[index + 1]
        }
        if rowSelection.count == 1 {
            return rowSelection.first
        }
        return nil
    }

    private func isRowSelected(_ entry: FileEntry, highlight: URL?) -> Bool {
        if rowSelection.contains(entry.url) { return true }
        guard let highlight else { return false }
        return Favorites.key(for: entry.url) == Favorites.key(for: highlight)
    }

    private func isLastColumn(_ index: Int) -> Bool {
        index == columnFolders.count - 1
    }

    private func dragSelection(for entry: FileEntry) -> Set<URL> {
        if rowSelection.contains(entry.url) { return rowSelection }
        return [entry.url]
    }

    private func contextURLs(for url: URL) -> [URL] {
        if rowSelection.contains(url) {
            return Array(rowSelection)
        }
        return [url]
    }

    private func entryLookup(_ url: URL) -> FileEntry? {
        for entries in columnEntries.values {
            if let match = entries.first(where: { Favorites.key(for: $0.url) == Favorites.key(for: url) }) {
                return match
            }
        }
        return model.entries.first { Favorites.key(for: $0.url) == Favorites.key(for: url) }
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

    private func isRenaming(_ url: URL) -> Bool {
        guard let session = rename.session else { return false }
        return Favorites.key(for: session.url) == Favorites.key(for: url)
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
