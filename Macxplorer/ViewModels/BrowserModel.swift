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

    func loadChildren(of node: FolderNode) async {
        let path = node.url.path
        let ticket = (childTickets[path] ?? 0) + 1
        childTickets[path] = ticket
        let generation = listingGeneration
        let includeHidden = showHiddenInSidebar
        node.loadState = .loading

        do {
            let listed = try await FileSystemService.listDirectory(at: node.url, showHidden: includeHidden)
            guard childTickets[path] == ticket, generation == listingGeneration else { return }
            node.children = listed.filter(\.opensAsFolder).map { entry in
                FolderNode(url: entry.url, name: entry.name)
            }
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

    private func reloadListings() async {
        await reloadTree()
        if let selectedURL {
            beginDetailLoad(selectedURL)
        }
    }

    private func reloadTree() async {
        listingGeneration += 1
        treeRevision += 1
        resetTree()
        pinnedPaths.removeAll()
        await reloadExpandedNodes()
        syncPinnedPath()
    }

    private func resetTree() {
        for root in roots {
            root.children = []
            root.loadState = .unloaded
            root.hasChildFolders = nil
        }
    }

    private func reloadExpandedNodes() async {
        await reload(nodes: roots)
    }

    private func reload(nodes: [FolderNode]) async {
        for node in nodes where expanded.contains(node.url) {
            await loadChildren(of: node)
            await reload(nodes: node.children)
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
