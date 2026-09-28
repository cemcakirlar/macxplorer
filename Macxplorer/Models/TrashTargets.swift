import Foundation

enum TrashTargets {
    /// Keeps ancestors and drops any selected item that lives inside another selected item.
    static func roots(among urls: [URL]) -> [URL] {
        let keyed = urls.map { (url: $0, key: Favorites.key(for: $0)) }
        var seen = Set<String>()
        return keyed.filter { candidate in
            let covered = keyed.contains { other in
                other.key != candidate.key && contains(candidate.key, in: other.key)
            }
            return !covered && seen.insert(candidate.key).inserted
        }.map(\.url)
    }

    /// `true` when `path` is a trashed item or a file inside one.
    static func affects(_ path: String, trashed roots: [String]) -> Bool {
        let current = Favorites.key(forPath: path)
        return roots.contains { ancestor in
            let key = Favorites.key(forPath: ancestor)
            return current == key || contains(current, in: key)
        }
    }

    /// Pulls a trashed folder, and everything inside it, up to that folder’s parent.
    /// A neighboring prefix such as `/Users/ab` stays put. The original string is returned when nothing changes.
    static func replacing(_ path: String, trashed roots: [String]) -> String {
        let current = Favorites.key(forPath: path)
        let matches = roots.map { Favorites.key(forPath: $0) }.filter { ancestor in
            current == ancestor || contains(current, in: ancestor)
        }
        guard let match = matches.min(by: { $0.count < $1.count }) else { return path }
        let parent = Favorites.key(for: URL(fileURLWithPath: match, isDirectory: true).deletingLastPathComponent())
        if parent == match {
            return path
        }
        return parent
    }

    static func url(_ url: URL, trashed roots: [URL]) -> URL {
        let rewritten = replacing(url.path, trashed: roots.map(\.path))
        if rewritten == url.path {
            return url
        }
        return URL(fileURLWithPath: rewritten, isDirectory: true)
    }

    private static func contains(_ path: String, in ancestor: String) -> Bool {
        guard ancestor != "/" else { return path != "/" }
        return path.hasPrefix(ancestor + "/")
    }
}
