import Foundation

enum ColumnPath {
    /// Folders from the deepest matching root through `url`, inclusive.
    static func folders(to url: URL, roots: [URL]) -> [URL] {
        let target = url.directoryKey
        let targetKey = Favorites.key(for: target)
        guard let root = deepestRoot(covering: targetKey, roots: roots) else {
            return [target]
        }
        let rootKey = Favorites.key(for: root)
        if rootKey == targetKey {
            return [root]
        }

        var folders = [root]
        var current = root
        let targetComponents = target.pathComponents
        let rootCount = root.pathComponents.count
        guard targetComponents.count > rootCount else { return [target] }

        for index in rootCount..<targetComponents.count {
            current = current.appendingPathComponent(targetComponents[index], isDirectory: true).directoryKey
            folders.append(current)
        }
        return folders
    }

    /// After selecting `item` in column `index`, the folder chain for the next layout.
    static func selectingFolder(_ item: URL, in folders: [URL], at index: Int) -> [URL] {
        let prefix = Array(folders.prefix(index + 1))
        return prefix + [item.directoryKey]
    }

    /// After selecting a file in column `index`, keep folders through that column only.
    static func selectingFile(in folders: [URL], at index: Int) -> [URL] {
        Array(folders.prefix(index + 1))
    }

    private static func deepestRoot(covering targetKey: String, roots: [URL]) -> URL? {
        roots
            .map(\.directoryKey)
            .filter { root in
                let rootKey = Favorites.key(for: root)
                if rootKey == targetKey { return true }
                if rootKey == "/" {
                    return targetKey.hasPrefix("/")
                }
                return targetKey.hasPrefix(rootKey + "/")
            }
            .max(by: { Favorites.key(for: $0).count < Favorites.key(for: $1).count })
    }
}
