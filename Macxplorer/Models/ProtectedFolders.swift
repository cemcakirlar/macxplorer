import Foundation

/// Folders the system owns, which Finder won't rename, trash, or move either.
enum ProtectedFolders {
    static let systemPaths: Set<String> = [
        "/Applications", "/Library", "/System", "/Users", "/Volumes",
        "/bin", "/cores", "/dev", "/etc", "/opt", "/private", "/sbin", "/tmp", "/usr", "/var",
    ]

    static let homeFolders: Set<String> = [
        "Applications", "Desktop", "Documents", "Downloads", "Library",
        "Movies", "Music", "Pictures", "Public",
    ]

    static func contains(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let key = Favorites.key(for: url)
        let homeKey = Favorites.key(for: home)
        if key == "/" || systemPaths.contains(key) || key == homeKey {
            return true
        }
        if homeKey.hasPrefix(key + "/") {
            return true
        }
        let parent = Favorites.key(for: URL(fileURLWithPath: key).deletingLastPathComponent())
        if parent == "/Users" {
            return true
        }
        return parent == homeKey && homeFolders.contains(URL(fileURLWithPath: key).lastPathComponent)
    }

    static func displayName(_ url: URL) -> String {
        FileManager.default.displayName(atPath: url.path)
    }
}
