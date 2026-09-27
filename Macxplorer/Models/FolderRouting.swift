import Foundation

enum FolderRouting {
    static func chain(from root: URL, to target: URL) -> [URL] {
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

        var urls = [rootURL]
        var current = rootURL
        for part in remainder.split(separator: "/") {
            current = current.appendingPathComponent(String(part)).directoryKey
            urls.append(current)
        }
        return urls
    }

    static func bestRoot(among roots: [URL], for target: URL) -> URL? {
        let path = target.directoryKey.path
        return roots
            .map(\.directoryKey)
            .filter { root in
                let rootPath = root.path
                if rootPath == "/" { return true }
                return path == rootPath || path.hasPrefix(rootPath + "/")
            }
            .max { $0.path.count < $1.path.count }
    }
}
