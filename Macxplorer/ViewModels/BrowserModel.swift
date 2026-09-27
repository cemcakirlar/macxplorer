import Foundation
import Observation

@MainActor
@Observable
final class BrowserModel {
    let roots: [FolderNode]
    var expanded: Set<URL> = []
    var selectedURL: URL?
    var scrollToURL: URL?
    var entries: [FileEntry] = []
    var detailError: String?
    var isLoadingDetail = false
    var showHidden = false

    private var listingGeneration = 0
    private var detailTicket = 0
    private var childTickets: [String: Int] = [:]
    private var detailTask: Task<Void, Never>?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        roots = [
            FolderNode(url: home, name: "Home"),
            FolderNode(url: URL(fileURLWithPath: "/", isDirectory: true), name: "Root"),
            FolderNode(url: URL(fileURLWithPath: "/Volumes", isDirectory: true), name: "Volumes"),
        ]
        selectedURL = home.directoryKey
    }

    func bootstrap() async {
        guard let selectedURL else { return }
        beginDetailLoad(selectedURL)
    }

    func select(_ url: URL) {
        let next = url.directoryKey
        guard next.path != selectedURL?.path else { return }
        selectedURL = next
        beginDetailLoad(next)
    }

    func navigate(to url: URL) async {
        let next = url.directoryKey
        selectedURL = next
        beginDetailLoad(next)
        await expandAncestors(of: next)
        selectedURL = next
        scrollToURL = next
    }

    func setShowHidden(_ show: Bool) async {
        guard show != showHidden else { return }
        showHidden = show
        await reloadListings()
    }

    func refresh() async {
        await reloadListings()
    }

    func loadChildren(of node: FolderNode) async {
        let path = node.url.path
        let ticket = (childTickets[path] ?? 0) + 1
        childTickets[path] = ticket
        let generation = listingGeneration
        let includeHidden = showHidden
        node.loadState = .loading

        do {
            let listed = try await FileSystemService.listDirectory(at: node.url, showHidden: includeHidden)
            guard childTickets[path] == ticket, generation == listingGeneration else { return }
            node.children = listed.filter(\.opensAsFolder).map { entry in
                FolderNode(url: entry.url, name: entry.name)
            }
            node.loadState = .loaded
        } catch {
            guard childTickets[path] == ticket, generation == listingGeneration else { return }
            node.children = []
            node.loadState = .failed(error.localizedDescription)
        }
    }

    private func beginDetailLoad(_ url: URL) {
        detailTicket += 1
        let ticket = detailTicket
        let generation = listingGeneration
        entries = []
        detailError = nil
        isLoadingDetail = true
        detailTask?.cancel()
        detailTask = Task { await self.loadDetail(at: url, ticket: ticket, generation: generation) }
    }

    private func loadDetail(at url: URL, ticket: Int, generation: Int) async {
        let includeHidden = showHidden
        do {
            let listed = try await FileSystemService.listDirectory(at: url, showHidden: includeHidden)
            guard ticket == detailTicket, generation == listingGeneration else { return }
            guard selectedURL?.path == url.directoryKey.path else { return }
            entries = listed
            detailError = nil
        } catch is CancellationError {
            return
        } catch {
            guard ticket == detailTicket, generation == listingGeneration else { return }
            entries = []
            detailError = error.localizedDescription
        }
        guard ticket == detailTicket else { return }
        isLoadingDetail = false
    }

    private func reloadListings() async {
        listingGeneration += 1
        resetTree()
        await reloadExpandedNodes()
        if let selectedURL {
            beginDetailLoad(selectedURL)
        }
    }

    private func resetTree() {
        for root in roots {
            root.children = []
            root.loadState = .unloaded
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
        let chain = pathChain(from: root.url, to: target)
        guard chain.count > 1 else { return }

        for ancestor in chain.dropLast() {
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

    private func bestRoot(for url: URL) -> FolderNode? {
        let path = url.directoryKey.path
        return roots
            .filter { root in
                let rootPath = root.url.path
                if rootPath == "/" { return true }
                return path == rootPath || path.hasPrefix(rootPath + "/")
            }
            .max { $0.url.path.count < $1.url.path.count }
    }

    private func pathChain(from root: URL, to target: URL) -> [URL] {
        let rootURL = root.directoryKey
        let targetURL = target.directoryKey
        let rootPath = rootURL.path
        let targetPath = targetURL.path
        if targetPath == rootPath { return [rootURL] }

        let remainder: String
        if rootPath == "/" {
            guard targetPath.hasPrefix("/") else { return [rootURL] }
            remainder = String(targetPath.dropFirst())
        } else {
            let prefix = rootPath + "/"
            guard targetPath.hasPrefix(prefix) else { return [rootURL] }
            remainder = String(targetPath.dropFirst(prefix.count))
        }

        var chain = [rootURL]
        var current = rootURL
        for part in remainder.split(separator: "/") {
            current = current.appendingPathComponent(String(part)).directoryKey
            chain.append(current)
        }
        return chain
    }

    private func findNode(_ url: URL, in nodes: [FolderNode]) -> FolderNode? {
        let path = url.directoryKey.path
        for node in nodes {
            if node.url.path == path { return node }
            if let found = findNode(url, in: node.children) { return found }
        }
        return nil
    }
}
