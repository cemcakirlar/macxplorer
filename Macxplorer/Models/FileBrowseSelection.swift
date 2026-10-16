import AppKit
import Foundation

enum FileBrowseSelection {
    static func select(
        _ url: URL,
        flags: NSEvent.ModifierFlags,
        orderedURLs: [URL],
        selection: inout Set<URL>
    ) {
        if flags.contains(.command) {
            if selection.contains(url) {
                selection.remove(url)
            } else {
                selection.insert(url)
            }
            return
        }
        if flags.contains(.shift) {
            let anchor = selection.first ?? url
            guard
                let start = orderedURLs.firstIndex(where: { Favorites.key(for: $0) == Favorites.key(for: anchor) }),
                let end = orderedURLs.firstIndex(where: { Favorites.key(for: $0) == Favorites.key(for: url) })
            else {
                selection = [url]
                return
            }
            selection = Set(orderedURLs[min(start, end)...max(start, end)])
            return
        }
        selection = [url]
    }

    static func dragURLs(for url: URL, selection: Set<URL>) -> [URL] {
        if selection.contains(url) {
            return selection.sorted { $0.path < $1.path }
        }
        return [url]
    }

    static func open(_ entry: FileEntry, navigate: (URL) -> Void) {
        if let folder = FolderOpenTarget.url(for: entry.url, opensAsFolder: entry.opensAsFolder) {
            navigate(folder)
        } else {
            NSWorkspace.shared.open(entry.url)
        }
    }
}
