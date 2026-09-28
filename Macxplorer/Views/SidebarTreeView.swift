import AppKit
import SwiftUI

struct SidebarTreeView: View {
    var model: BrowserModel
    var actions: ItemActions
    var rename: RenameEditing
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: selection) {
                if !model.favoritePaths.isEmpty {
                    Section("Favorites") {
                        ForEach(model.favoritePaths, id: \.self) { path in
                            FavoriteRow(
                                path: path,
                                isAvailable: model.favoriteIsAvailable(path),
                                isSelected: model.sidebarSelection == .favorite(path),
                                rename: rename,
                                receiveDrop: receiveDrop,
                                onSelect: { model.selectInSidebar(.favorite(path)) }
                            )
                        }
                        .onMove { source, destination in
                            model.moveFavorites(from: source, to: destination)
                        }
                    }
                }
                Section {
                    ForEach(model.roots) { node in
                        SidebarBranch(model: model, node: node, rename: rename, receiveDrop: receiveDrop)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Folders")
            // A menu on the disclosure group covers every nested row and keeps the ancestor URL.
            .contextMenu(forSelectionType: SidebarSelection.self) { items in
                contextMenu(for: items)
            }
            .onKeyPress(.return) {
                guard rename.session == nil else { return .ignored }
                switch model.sidebarSelection {
                case .favorite(let path):
                    guard model.favoriteIsAvailable(path) else { return .ignored }
                    rename.begin(URL(fileURLWithPath: path, isDirectory: true))
                case .folder(let url):
                    rename.begin(url)
                case nil:
                    return .ignored
                }
                return .handled
            }
            .onKeyPress(keys: [.delete, .deleteForward], phases: .down) { press in
                guard rename.session == nil, TrashShortcut.matches(press.modifiers) else { return .ignored }
                switch model.sidebarSelection {
                case .favorite(let path):
                    guard model.favoriteIsAvailable(path) else { return .ignored }
                    actions.moveToTrash([URL(fileURLWithPath: path, isDirectory: true)])
                case .folder(let url):
                    actions.moveToTrash([url])
                case nil:
                    return .ignored
                }
                return .handled
            }
            .focusedSceneValue(\.fileCopyAction, FileCopyAction(urls: copiedURLs))
            .onChange(of: model.scrollToURL) { _, url in
                guard let url else { return }
                Task { @MainActor in
                    proxy.scrollTo(url, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for items: Set<SidebarSelection>) -> some View {
        let favoritePaths = items.compactMap { item -> String? in
            if case .favorite(let path) = item { return path }
            return nil
        }
        if !favoritePaths.isEmpty {
            ItemContextMenu(
                urls: favoritePaths.map { URL(fileURLWithPath: $0, isDirectory: true) },
                opensAsFolder: { _ in true },
                actions: actions,
                favorite: FavoriteMenuItem(action: .remove(favoritePaths), perform: model.applyFavorites),
                targetIsMissing: !favoritePaths.allSatisfy(model.favoriteIsAvailable),
                canCreateFolder: model.selectedURL != nil
            )
        } else {
            let urls = items.compactMap { item -> URL? in
                if case .folder(let url) = item { return url }
                return nil
            }
            ItemContextMenu(
                urls: urls,
                opensAsFolder: { _ in true },
                actions: actions,
                favorite: model.favoriteMenuAction(for: urls).map {
                    FavoriteMenuItem(action: $0, perform: model.applyFavorites)
                },
                canCreateFolder: model.selectedURL != nil
            )
        }
    }

    private var copiedURLs: [URL] {
        switch model.sidebarSelection {
        case .favorite(let path):
            guard model.favoriteIsAvailable(path) else { return [] }
            return [URL(fileURLWithPath: path, isDirectory: true)]
        case .folder(let url):
            return [url]
        case nil:
            return []
        }
    }

    private var selection: Binding<SidebarSelection?> {
        Binding(
            get: { model.sidebarSelection },
            set: { selection in
                guard let selection else { return }
                model.selectInSidebar(selection)
            }
        )
    }
}

private struct FavoriteRow: View {
    var path: String
    var isAvailable: Bool
    var isSelected: Bool
    var rename: RenameEditing
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: IconStore.shared.image(for: url, isDirectory: true))
                .resizable()
                .frame(width: 16, height: 16)
                .opacity(isAvailable ? 1 : 0.4)
            name
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .help(path)
        .tag(SidebarSelection.favorite(path))
        .onDrop(
            of: [.fileURL],
            delegate: FileDropDelegate(
                target: isAvailable ? .folder(url) : .missing,
                receive: receiveDrop
            )
        )
        .overlay {
            if isAvailable, !isRenaming {
                RenameClickCatcher(
                    isSelected: isSelected,
                    onSlowClick: { rename.begin(url) },
                    onDoubleClick: nil,
                    onPrimaryClick: { _ in onSelect() },
                    fileDragRow: isAvailable ? url : nil,
                    fileDragSelection: [url]
                )
            }
        }
    }

    @ViewBuilder
    private var name: some View {
        if isRenaming {
            InlineRenameField(
                draft: rename.draft,
                isFolder: true,
                refocusID: rename.refocusID,
                onCommit: rename.commit,
                onCancel: rename.cancel
            )
        } else {
            Text(FileManager.default.displayName(atPath: path))
                .lineLimit(1)
                .foregroundStyle(isAvailable ? .primary : .tertiary)
        }
    }

    private var isRenaming: Bool {
        guard let session = rename.session else { return false }
        return Favorites.key(for: session.url) == Favorites.key(forPath: path)
    }

    private var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}

private struct SidebarBranch: View {
    var model: BrowserModel
    var node: FolderNode
    var rename: RenameEditing
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void

    var body: some View {
        expandedBranch
    }

    private var expandedBranch: some View {
        trackExpansion()
        return Group {
            if showsDisclosure {
                DisclosureGroup(isExpanded: expansion) {
                    branchContent
                } label: {
                    row
                }
            } else {
                row
            }
        }
        .task(id: model.treeRevision) {
            await model.probeChildFolders(of: node)
        }
    }

    /// Tag stays on the label. On the disclosure group, nested rows resolve to this folder.
    private var row: some View {
        rowLabel
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay {
                if !isRenaming {
                    RenameClickCatcher(
                        isSelected: model.sidebarSelection == .folder(node.url),
                        onSlowClick: { rename.begin(node.url) },
                        onDoubleClick: nil,
                        onPrimaryClick: { _ in model.selectInSidebar(.folder(node.url)) },
                        fileDragRow: node.url,
                        fileDragSelection: [node.url]
                    )
                }
            }
            .tag(SidebarSelection.folder(node.url))
            .id(node.url)
            .onDrop(
                of: [.fileURL],
                delegate: FileDropDelegate(target: .folder(node.url), receive: receiveDrop)
            )
    }

    private var showsDisclosure: Bool {
        switch node.loadState {
        case .loaded:
            return !node.children.isEmpty
        case .loading, .failed:
            return true
        case .unloaded:
            return node.hasChildFolders == true
        }
    }

    /// `DisclosureGroup` reads its binding outside `body`, so a double-click expand
    /// would not refresh this row unless `body` also touches `model.expanded`.
    private func trackExpansion() {
        _ = model.expanded
    }

    private var rowLabel: some View {
        HStack(spacing: 6) {
            Image(nsImage: IconStore.shared.image(for: node.url, isDirectory: true))
                .resizable()
                .frame(width: 16, height: 16)
            if isRenaming {
                InlineRenameField(
                    draft: rename.draft,
                    isFolder: true,
                    refocusID: rename.refocusID,
                    onCommit: rename.commit,
                    onCancel: rename.cancel
                )
            } else {
                Text(node.name)
                    .lineLimit(1)
            }
        }
    }

    private var isRenaming: Bool {
        rename.session?.url.directoryKey.path == node.url.path
    }

    @ViewBuilder
    private var branchContent: some View {
        switch node.loadState {
        case .unloaded, .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        case .loaded:
            ForEach(node.children) { child in
                SidebarBranch(model: model, node: child, rename: rename, receiveDrop: receiveDrop)
            }
        }
    }

    private var expansion: Binding<Bool> {
        Binding(
            get: { model.expanded.contains(node.url) },
            set: { newValue in
                if newValue {
                    model.expanded.insert(node.url)
                    if node.loadState == .unloaded || node.loadState.isFailed {
                        Task { await model.loadChildren(of: node) }
                    }
                } else {
                    model.expanded.remove(node.url)
                }
            }
        )
    }

}
