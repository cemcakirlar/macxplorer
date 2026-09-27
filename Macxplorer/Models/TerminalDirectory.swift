import Foundation

enum TerminalDirectory {
    /// Folders open themselves. Files open their parent.
    static func url(for item: URL, opensAsFolder: Bool) -> URL {
        if opensAsFolder {
            return item.directoryKey
        }
        return item.deletingLastPathComponent().directoryKey
    }

    /// One entry per folder, in path order.
    static func urls(for items: some Sequence<URL>, opensAsFolder: (URL) -> Bool) -> [URL] {
        var seen = Set<String>()
        var directories: [URL] = []
        for item in items.sorted(by: { $0.path < $1.path }) {
            let directory = url(for: item, opensAsFolder: opensAsFolder(item))
            if seen.insert(directory.path).inserted {
                directories.append(directory)
            }
        }
        return directories.sorted { $0.path < $1.path }
    }
}
