import Foundation

struct NavigationHistory: Equatable {
    private(set) var backStack: [URL] = []
    private(set) var forwardStack: [URL] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    mutating func recordVisit(from current: URL?, to next: URL) {
        guard let current else { return }
        let origin = current.directoryKey
        let destination = next.directoryKey
        guard origin.path != destination.path else { return }
        backStack.append(origin)
        forwardStack.removeAll()
    }

    mutating func goBack(from current: URL?) -> URL? {
        guard let current, let previous = backStack.popLast() else { return nil }
        forwardStack.append(current.directoryKey)
        return previous
    }

    mutating func rewrite(from oldURL: URL, to newURL: URL) {
        backStack = backStack.map { RenamedPath.url($0, from: oldURL, to: newURL) }
        forwardStack = forwardStack.map { RenamedPath.url($0, from: oldURL, to: newURL) }
    }

    mutating func drop(trashed urls: [URL]) {
        backStack = collapsing(backStack.map { TrashTargets.url($0, trashed: urls) })
        forwardStack = collapsing(forwardStack.map { TrashTargets.url($0, trashed: urls) })
    }

    private func collapsing(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            if result.last?.directoryKey.path != url.directoryKey.path {
                result.append(url)
            }
        }
        return result
    }

    mutating func goForward(from current: URL?) -> URL? {
        guard let current, let next = forwardStack.popLast() else { return nil }
        backStack.append(current.directoryKey)
        return next
    }
}

enum FolderNavigation {
    static func parent(of url: URL) -> URL? {
        let current = url.directoryKey
        let parent = current.deletingLastPathComponent().directoryKey
        guard parent.path != current.path else { return nil }
        return parent
    }
}
