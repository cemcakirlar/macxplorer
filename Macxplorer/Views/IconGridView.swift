import AppKit
import SwiftUI

struct IconGridView: View {
    var model: BrowserModel
    @Binding var rowSelection: Set<URL>
    var actions: ItemActions
    var rename: RenameEditing
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void
    var nameFilter: String = ""
    var onClearFilter: (() -> Void)? = nil
    @Binding var typeAhead: TypeAheadBuffer
    var searchFieldFocused: Bool = false
    @State private var hoveredDrop = DropHoverTracker()

    private let iconPointSize = IconStore.gridPointSize
    private let cellMinimum: CGFloat = 96

    var body: some View {
        FileBrowseChrome(
            model: model,
            nameFilter: nameFilter,
            onClearFilter: onClearFilter,
            receiveDrop: receiveDrop
        ) {
            grid
        }
        .focusedSceneValue(\.fileCopyAction, FileCopyAction(urls: copiedURLs))
        .task(id: prefetchKey) {
            await IconStore.shared.prefetch(rows.map(\.url), pointSize: iconPointSize)
        }
    }

    private var copiedURLs: [URL] {
        rowSelection.sorted { $0.path < $1.path }
    }

    private var rows: [FileEntry] {
        FileNameFilter.filtered(FileListOrder.sorted(model.entries), query: nameFilter)
    }

    private var prefetchKey: String {
        rows.map { Favorites.key(for: $0.url) }.joined(separator: "\n")
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: cellMinimum), spacing: 12, alignment: .top)],
                spacing: 16
            ) {
                ForEach(rows) { entry in
                    iconCell(entry)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture {
                rowSelection = []
            }
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
            visibleRows: rows,
            selection: &nextSelection
        )
        if result == .handled {
            typeAhead = nextBuffer
            rowSelection = nextSelection
        }
        return result
    }

    private func iconCell(_ entry: FileEntry) -> some View {
        let selected = rowSelection.contains(entry.url)
        return VStack(spacing: 6) {
            Image(nsImage: IconStore.shared.image(
                for: entry.url,
                isDirectory: entry.opensAsFolder,
                pointSize: iconPointSize
            ))
            .resizable()
            .interpolation(.high)
            .frame(width: iconPointSize, height: iconPointSize)

            if isRenaming(entry.url) {
                InlineRenameField(
                    draft: rename.draft,
                    isFolder: rename.session?.isFolder == true,
                    refocusID: rename.refocusID,
                    onCommit: rename.commit,
                    onCancel: rename.cancel
                )
                .frame(maxWidth: cellMinimum)
            } else {
                Text(entry.name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: cellMinimum)
            }
        }
        .padding(8)
        .frame(minWidth: cellMinimum, maxWidth: cellMinimum + 16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.clear)
        }
        .background {
            if DropHover.contains(hoveredDrop.url, folder: entry.url) {
                DropTargetHighlight(edge: .all)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            if !isRenaming(entry.url) {
                RenameClickCatcher(
                    isSelected: selected,
                    onSlowClick: { rename.begin(entry.url) },
                    onDoubleClick: {
                        FileBrowseSelection.open(entry) { url in
                            Task { await model.navigate(to: url) }
                        }
                    },
                    onPrimaryClick: { flags in
                        select(entry.url, flags: flags)
                    },
                    fileDragRow: entry.url,
                    fileDragSelection: FileBrowseSelection.dragURLs(for: entry.url, selection: rowSelection)
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
                    model.entries.first { $0.url == url }?.opensAsFolder == true
                },
                actions: listActions,
                favorite: model.favoriteMenuAction(for: contextURLs(for: entry.url)).map {
                    FavoriteMenuItem(action: $0, perform: model.applyFavorites)
                }
            )
        }
        .highPriorityGesture(TapGesture().onEnded {})
    }

    private func select(_ url: URL, flags: NSEvent.ModifierFlags) {
        var next = rowSelection
        FileBrowseSelection.select(url, flags: flags, orderedURLs: rows.map(\.url), selection: &next)
        rowSelection = next
    }

    private func contextURLs(for url: URL) -> [URL] {
        if rowSelection.contains(url) {
            return Array(rowSelection)
        }
        return [url]
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
