import Foundation

enum FolderOpenTarget {
    /// Real folders open as themselves. An alias or symlink opens in the browser
    /// only when its target is a folder and not a package.
    static func url(for itemURL: URL, opensAsFolder: Bool) -> URL? {
        if opensAsFolder {
            return itemURL
        }
        guard let values = try? itemURL.resourceValues(forKeys: [.isAliasFileKey]),
              values.isAliasFile == true,
              let resolved = try? URL(resolvingAliasFileAt: itemURL)
        else {
            return nil
        }
        guard let target = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
              target.isDirectory == true,
              target.isPackage != true
        else {
            return nil
        }
        return resolved
    }
}
