import Foundation

enum Favorites {
    enum MenuAction: Equatable {
        case add([String])
        case remove([String])

        var title: String {
            switch self {
            case .add: return "Add to Favorites"
            case .remove: return "Remove from Favorites"
            }
        }
    }

    /// Favorite identity. Cleans `.`, `..` and trailing slashes without resolving symlinks,
    /// so a symlink stays a separate favorite from its target.
    static func key(for url: URL) -> String {
        key(forPath: url.path)
    }

    static func key(forPath path: String) -> String {
        var parts: [Substring] = []
        for part in path.split(separator: "/", omittingEmptySubsequences: true) {
            switch part {
            case ".":
                continue
            case "..":
                if !parts.isEmpty { parts.removeLast() }
            default:
                parts.append(part)
            }
        }
        return "/" + parts.joined(separator: "/")
    }

    /// `nil` when no candidate is eligible. Adds only the missing ones unless all are already favorites.
    static func menuAction(for candidates: [String], favorites: [String]) -> MenuAction? {
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return nil }
        let existing = Set(favorites)
        let missing = unique.filter { !existing.contains($0) }
        return missing.isEmpty ? .remove(unique) : .add(missing)
    }

    /// Updates favorites that are `oldPath` or inside it. Unrelated paths, including a longer prefix, stay as stored.
    static func rewriting(_ favorites: [String], from oldPath: String, to newPath: String) -> [String] {
        var seen = Set<String>()
        return favorites.compactMap { path in
            let rewritten = RenamedPath.rewriting(path, from: oldPath, to: newPath)
            return seen.insert(rewritten).inserted ? rewritten : nil
        }
    }

    static func applying(_ action: MenuAction, to favorites: [String]) -> [String] {
        switch action {
        case .add(let paths):
            var result = favorites
            for path in paths where !result.contains(path) {
                result.append(path)
            }
            return result
        case .remove(let paths):
            let removed = Set(paths)
            return favorites.filter { !removed.contains($0) }
        }
    }

    /// Same semantics as SwiftUI `onMove`: `destination` is an offset in the list before the move.
    static func moving(_ favorites: [String], from source: IndexSet, to destination: Int) -> [String] {
        let moved = source.filter { favorites.indices.contains($0) }.map { favorites[$0] }
        var rest = favorites.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let shift = source.filter { $0 < destination }.count
        let insertAt = min(max(destination - shift, 0), rest.count)
        rest.insert(contentsOf: moved, at: insertAt)
        return rest
    }

    /// Folders, volumes and symlinks to folders. Files, packages and Finder aliases are excluded.
    static func opensAsFolder(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        guard let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else {
            return false
        }
        return values.isDirectory == true && values.isPackage != true
    }
}
