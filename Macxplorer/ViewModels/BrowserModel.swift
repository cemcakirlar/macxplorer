import Foundation
import Observation

enum SidebarSelection: Hashable {
    case favorite(String)
    case folder(URL)
}

@MainActor
@Observable
final class BrowserModel {
    let roots: [FolderNode]
    var expanded: Set<URL> = []
    var selectedURL: URL?
    /// Set only by a favorite click. Any other navigation highlights the tree row instead.
    private(set) var selectedFavorite: String?
    var scrollToURL: URL?
    var entries: [FileEntry] = []
    var detailError: String?
    var isLoadingDetail = false
    var showHiddenInList = false
    var showHiddenInSidebar = false
    var treeRevision = 0

    private var history = NavigationHistory()
    private var pinnedPaths: Set<String> = []
    private var listingGeneration = 0
    private var probeTickets: [String: Int] = [:]
    private var detailTicket = 0
    private var childTickets: [String: Int] = [:]
    private var detailTask: Task<Void, Never>?
    private var detailIconTask: Task<Void, Never>?
    private var treeIconTask: Task<Void, Never>?
    private var pathIconTask: Task<Void, Never>?
    private var selectionHold = SelectionHold()
    private let settings: AppSettings

    var canGoBack: Bool { history.canGoBack }
    var canGoForward: Bool { history.canGoForward }
    var canGoUp: Bool {
        guard let selectedURL else { return false }
        return FolderNavigation.parent(of: selectedURL) != nil
    }

    init(settings: AppSettings = .shared) {
        self.settings = settings
        showHiddenInList = settings.showHidden
        showHiddenInSidebar = settings.showHiddenInSidebar
        let home = FileManager.default.homeDirectoryForCurrentUser
        roots = [
            FolderNode(url: home, name: SidebarRootLabel.home),
            FolderNode(url: URL(fileURLWithPath: "/", isDirectory: true), name: SidebarRootLabel.root),
            FolderNode(url: URL(fileURLWithPath: "/Volumes", isDirectory: true), name: SidebarRootLabel.volumes),
        ]
        selectedURL = LaunchFolder.url(
            reopenLastFolder: settings.reopenLastFolder,
            lastPath: settings.lastFolderPath,
            home: home,
            directoryExists: Self.directoryExists
        )
        applyRootLabels()
    }

    func applyRootLabels() {
        let stored = [
            settings.sidebarRootHome,
            settings.sidebarRootRoot,
            settings.sidebarRootVolumes,
        ]
        let fallbacks = [
            SidebarRootLabel.home,
            SidebarRootLabel.root,
            SidebarRootLabel.volumes,
        ]
        for index in roots.indices {
            roots[index].name = SidebarRootLabel.resolved(stored[index], fallback: fallbacks[index])
        }
    }

    func bootstrap() async {
        guard let selectedURL else { return }
        if settings.reopenLastFolder {
            await navigate(to: selectedURL, recordsHistory: false)
        } else {
            beginDetailLoad(selectedURL)
        }
    }

    var favoritePaths: [String] { settings.favoritePaths }

    var sidebarSelection: SidebarSelection? {
        if let selectedFavorite { return .favorite(selectedFavorite) }
        return selectedURL.map(SidebarSelection.folder)
    }

    func selectInSidebar(_ selection: SidebarSelection) {
        switch selection {
        case .favorite(let path):
            selectFavorite(path)
        case .folder(let url):
            selectedFavorite = nil
            select(url)
        }
    }

    func favoriteIsAvailable(_ path: String) -> Bool {
        Favorites.opensAsFolder(URL(fileURLWithPath: path, isDirectory: true))
    }

    /// Files, packages and aliases in `urls` are skipped.
    func favoriteMenuAction(for urls: [URL]) -> Favorites.MenuAction? {
        let candidates = urls.filter(Favorites.opensAsFolder).map(Favorites.key(for:))
        return Favorites.menuAction(for: candidates, favorites: settings.favoritePaths)
    }

    func applyFavorites(_ action: Favorites.MenuAction) {
        settings.favoritePaths = Favorites.applying(action, to: settings.favoritePaths)
        if let selectedFavorite, !settings.favoritePaths.contains(selectedFavorite) {
            self.selectedFavorite = nil
        }
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        settings.favoritePaths = Favorites.moving(settings.favoritePaths, from: source, to: destination)
    }

    private func selectFavorite(_ path: String) {
        guard favoriteIsAvailable(path) else { return }
        select(URL(fileURLWithPath: path, isDirectory: true))
        selectedFavorite = path
    }

    func select(_ url: URL) {
        let next = url.directoryKey
        guard next.path != selectedURL?.path else { return }
        recordVisit(to: next)
        selectedURL = next
        settings.rememberFolder(next)
        beginDetailLoad(next)
        syncPinnedPath()
    }

    func navigate(to url: URL, recordsHistory: Bool = true) async {
        let next = url.directoryKey
        if recordsHistory {
            recordVisit(to: next)
        }
        appLogger.info("Opening \(next.path, privacy: .public)")
        selectedFavorite = nil
        selectedURL = next
        settings.rememberFolder(next)
        beginDetailLoad(next)
        await expandAncestors(of: next)
        selectedURL = next
        syncPinnedPath()
        scrollToURL = next
    }

    func goBack() async {
        var snapshot = history
        guard let target = snapshot.goBack(from: selectedURL) else { return }
        history = snapshot
        await navigate(to: target, recordsHistory: false)
    }

    func goForward() async {
        var snapshot = history
        guard let target = snapshot.goForward(from: selectedURL) else { return }
        history = snapshot
        await navigate(to: target, recordsHistory: false)
    }

    func goUp() async {
        guard let selectedURL, let parent = FolderNavigation.parent(of: selectedURL) else { return }
        await navigate(to: parent)
    }

    func setShowHiddenInList(_ show: Bool) async {
        guard show != showHiddenInList else { return }
        showHiddenInList = show
        if let selectedURL {
            beginDetailLoad(selectedURL)
        }
    }

    func setShowHiddenInSidebar(_ show: Bool) async {
        guard show != showHiddenInSidebar else { return }
        showHiddenInSidebar = show
        await reloadTree()
    }

    func refresh() async {
        await reloadListings()
    }

    /// Reloads the open folder and expanded sidebar without clearing what is already on screen.
    /// Returns false during the first load, when there is nothing to keep visible.
    func refreshVisible() async -> Bool {
        guard let selectedURL else { return false }
        guard !(isLoadingDetail && entries.isEmpty) else { return false }
        await reloadExpandedTree()
        await reloadDetailInPlace(selectedURL)
        return true
    }

    /// Reloads expanded sidebar folders in place. Does not touch the open-folder listing.
    func reloadExpandedTree() async {
        listingGeneration += 1
        await reload(nodes: roots, showsLoading: false)
        syncPinnedPath()
    }

    /// Keeps the current list selection when the next `selectedURL` change is `destination`.
    func holdListSelection(across destination: URL) {
        selectionHold.arm(for: destination)
    }

    /// Waits for the listing already started by navigation. Does not start another reload.
    func listedMatches(for urls: [URL]) async -> [URL] {
        await detailTask?.value
        return matchingEntries(urls)
    }

    /// Reloads the open folder and returns the listed URL for `url`, if it appears.
    func refreshedEntry(matching url: URL) async -> URL? {
        let matches = await refreshedEntries(matching: [url])
        return matches.first
    }

    /// Reloads the open folder and returns the listed URLs that match `urls`.
    func refreshedEntries(matching urls: [URL]) async -> [URL] {
        await refresh()
        await detailTask?.value
        return matchingEntries(urls)
    }

    private func matchingEntries(_ urls: [URL]) -> [URL] {
        let keys = Set(urls.map { Favorites.key(for: $0) })
        return entries.filter { keys.contains(Favorites.key(for: $0.url)) }.map(\.url)
    }

    /// Moves open-folder state onto `newURL` when the renamed item is that folder or a parent of it.
    func applyRenamedItem(from oldURL: URL, to newURL: URL) async {
        history.rewrite(from: oldURL, to: newURL)
        expanded = Set(expanded.map { RenamedPath.url($0, from: oldURL, to: newURL) })
        settings.favoritePaths = Favorites.rewriting(settings.favoritePaths, from: oldURL.path, to: newURL.path)
        if let selectedFavorite {
            let updated = RenamedPath.rewriting(selectedFavorite, from: oldURL.path, to: newURL.path)
            if updated != selectedFavorite {
                self.selectedFavorite = updated
            }
        }
        if let selectedURL {
            let updated = RenamedPath.url(selectedURL, from: oldURL, to: newURL)
            if updated.path != selectedURL.path {
                selectionHold.arm(for: updated)
                self.selectedURL = updated.directoryKey
            }
        }
        await refresh()
    }

    func consumeSelectionHold(for url: URL?) -> Bool {
        selectionHold.consume(for: url)
    }

    /// Pulls the open folder, history, and expanded tree up when a trashed folder contained them.
    /// Favorite paths stay stored so they work again after the folder is put back.
    func applyTrashed(_ urls: [URL]) async {
        let roots = TrashTargets.roots(among: urls)
        guard !roots.isEmpty else { return }
        history.drop(trashed: roots)
        expanded = Set(expanded.map { TrashTargets.url($0, trashed: roots) })
        if let selectedFavorite,
           TrashTargets.affects(selectedFavorite, trashed: roots.map(\.path)) {
            self.selectedFavorite = nil
        }
        if let selectedURL {
            let updated = TrashTargets.url(selectedURL, trashed: roots)
            if updated.path != selectedURL.path {
                self.selectedURL = updated.directoryKey
            }
        }
        await refresh()
    }

    func probeChildFolders(of node: FolderNode) async {
        guard node.loadState == .unloaded, node.hasChildFolders == nil else { return }
        let path = node.url.path
        let ticket = (probeTickets[path] ?? 0) + 1
        probeTickets[path] = ticket
        let generation = listingGeneration
        let includeHidden = showHiddenInSidebar
        let found = await FileSystemService.containsListableFolder(at: node.url, showHidden: includeHidden)
        guard probeTickets[path] == ticket, generation == listingGeneration else { return }
        guard node.loadState == .unloaded, let found else { return }
        node.hasChildFolders = found
    }

    func loadChildren(of node: FolderNode, showsLoading: Bool = true) async {
        let path = node.url.path
        let ticket = (childTickets[path] ?? 0) + 1
        childTickets[path] = ticket
        let generation = listingGeneration
        let includeHidden = showHiddenInSidebar
        if showsLoading || node.loadState != .loaded {
            node.loadState = .loading
        }

        do {
            let listed = try await FileSystemService.listDirectory(at: node.url, showHidden: includeHidden)
            guard childTickets[path] == ticket, generation == listingGeneration else { return }
            node.children = folderNodes(listed, keeping: node.children)
            node.loadState = .loaded
            syncPinnedPath()
            scheduleIconPrefetch(node.children.map(\.url), forTree: true)
        } catch is CancellationError {
            return
        } catch {
            guard childTickets[path] == ticket, generation == listingGeneration else { return }
            node.children = []
            node.loadState = .failed(error.localizedDescription)
        }
    }

    private func recordVisit(to next: URL) {
        var snapshot = history
        snapshot.recordVisit(from: selectedURL, to: next)
        history = snapshot
    }

    private func beginDetailLoad(_ url: URL) {
        prefetchPathIcon(url)
        detailTicket += 1
        let ticket = detailTicket
        entries = []
        detailError = nil
        isLoadingDetail = true
        detailIconTask?.cancel()
        detailTask?.cancel()
        detailTask = Task { await self.loadDetail(at: url, ticket: ticket) }
    }

    private func loadDetail(at url: URL, ticket: Int) async {
        let includeHidden = showHiddenInList
        do {
            let listed = try await FileSystemService.listDirectory(at: url, showHidden: includeHidden)
            guard ticket == detailTicket else { return }
            guard selectedURL?.path == url.directoryKey.path else { return }
            entries = listed
            detailError = nil
            appLogger.info("Listed \(listed.count) items in \(url.path, privacy: .public)")
            scheduleIconPrefetch(listed.map(\.url), forTree: false)
        } catch is CancellationError {
            return
        } catch {
            guard ticket == detailTicket else { return }
            entries = []
            detailError = error.localizedDescription
            appLogger.info("Failed to list \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        guard ticket == detailTicket else { return }
        isLoadingDetail = false
    }

    private func prefetchPathIcon(_ url: URL) {
        pathIconTask?.cancel()
        pathIconTask = Task {
            await IconStore.shared.prefetch([url])
        }
    }

    private func scheduleIconPrefetch(_ urls: [URL], forTree: Bool) {
        let task = Task {
            await IconStore.shared.prefetch(urls)
        }
        if forTree {
            treeIconTask?.cancel()
            treeIconTask = task
        } else {
            detailIconTask?.cancel()
            detailIconTask = task
        }
    }

    private func reloadDetailInPlace(_ url: URL) async {
        detailTicket += 1
        let ticket = detailTicket
        detailIconTask?.cancel()
        detailTask?.cancel()
        let task = Task { await self.loadDetail(at: url, ticket: ticket) }
        detailTask = task
        await task.value
    }

    private func reloadListings() async {
        await reloadTree()
        if let selectedURL {
            beginDetailLoad(selectedURL)
        }
    }

    private func reloadTree() async {
        listingGeneration += 1
        clearUnloadedProbes(in: roots)
        treeRevision += 1
        await reload(nodes: roots, showsLoading: false)
        syncPinnedPath()
    }

    /// Keeps an already loaded subtree so a refresh does not collapse the outline and move the scroll.
    private func folderNodes(_ listed: [FileEntry], keeping existing: [FolderNode]) -> [FolderNode] {
        let kept = Dictionary(uniqueKeysWithValues: existing.map { (Favorites.key(for: $0.url), $0) })
        return listed.filter(\.opensAsFolder).map { entry in
            let key = Favorites.key(for: entry.url)
            if let node = kept[key] {
                node.name = entry.name
                return node
            }
            return FolderNode(url: entry.url, name: entry.name)
        }
    }

    private func clearUnloadedProbes(in nodes: [FolderNode]) {
        for node in nodes {
            if node.loadState == .unloaded {
                node.hasChildFolders = nil
            }
            clearUnloadedProbes(in: node.children)
        }
    }

    private func reload(nodes: [FolderNode], showsLoading: Bool) async {
        for node in nodes where expanded.contains(node.url) {
            await loadChildren(of: node, showsLoading: showsLoading)
            await reload(nodes: node.children, showsLoading: showsLoading)
        }
    }

    private func expandAncestors(of url: URL) async {
        let target = url.directoryKey
        guard let root = bestRoot(for: target) else { return }
        let chain = FolderRouting.chain(from: root.url, to: target)
        guard chain.count > 1 else { return }

        for ancestor in chain.dropLast() {
            syncPinnedPath()
            guard let node = findNode(ancestor, in: roots) else { return }
            let needsLoad = node.loadState != .loaded
            if needsLoad {
                node.loadState = .loading
            }
            expanded.insert(node.url)
            if needsLoad {
                await loadChildren(of: node)
            }
        }
    }

    private func syncPinnedPath() {
        guard !showHiddenInSidebar else {
            pinnedPaths.removeAll()
            return
        }
        guard let selectedURL, let root = bestRoot(for: selectedURL) else {
            removePinnedPaths(pinnedPaths)
            pinnedPaths.removeAll()
            return
        }
        let chain = FolderRouting.chain(from: root.url, to: selectedURL)
        var childPathsByParent: [String: Set<String>] = [:]
        for index in chain.indices.dropFirst() {
            let parentURL = chain[index - 1]
            guard let parent = findNode(parentURL, in: roots), parent.loadState == .loaded else { continue }
            childPathsByParent[parent.url.path] = Set(parent.children.map(\.url.path))
        }
        let missing = SidebarPathPin.missingLinks(chain: chain, childPathsByParent: childPathsByParent)
        for link in missing {
            guard Self.directoryExists(link.child), Self.directoryIsReadable(link.child) else { continue }
            guard let parent = findNode(URL(fileURLWithPath: link.parent, isDirectory: true), in: roots) else { continue }
            let childURL = URL(fileURLWithPath: link.child, isDirectory: true).directoryKey
            let name = FileManager.default.displayName(atPath: childURL.path)
            parent.children.append(FolderNode(url: childURL, name: name))
            parent.children.sort { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            pinnedPaths.insert(childURL.path)
        }
        let stale = SidebarPathPin.stalePins(pinned: pinnedPaths, chain: chain)
        removePinnedPaths(stale)
        pinnedPaths.subtract(stale)
    }

    private func removePinnedPaths(_ stale: Set<String>) {
        guard !stale.isEmpty else { return }
        func walk(_ nodes: [FolderNode]) {
            for node in nodes {
                node.children.removeAll { stale.contains($0.url.path) }
                walk(node.children)
            }
        }
        walk(roots)
    }

    private func bestRoot(for url: URL) -> FolderNode? {
        guard let match = FolderRouting.bestRoot(among: roots.map(\.url), for: url) else {
            return nil
        }
        return roots.first { $0.url.path == match.path }
    }

    private func findNode(_ url: URL, in nodes: [FolderNode]) -> FolderNode? {
        let path = url.directoryKey.path
        for node in nodes {
            if node.url.path == path { return node }
            if let found = findNode(url, in: node.children) { return found }
        }
        return nil
    }

    private static func directoryExists(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func directoryIsReadable(_ path: String) -> Bool {
        FileManager.default.isReadableFile(atPath: path)
    }
}
