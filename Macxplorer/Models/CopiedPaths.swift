import Foundation

enum CopiedPaths {
    /// POSIX paths, sorted, one per line. Empty input is an empty string.
    static func text(for urls: some Sequence<URL>) -> String {
        sortedPaths(urls).joined(separator: "\n")
    }

    /// File names in the same order as `text(for:)`.
    static func names(for urls: some Sequence<URL>) -> String {
        sortedPaths(urls).map(name(for:)).joined(separator: "\n")
    }

    /// Home-relative paths (`~/...`). Paths outside `home` stay absolute.
    /// Same order as `text(for:)`.
    static func abbreviatedText(for urls: some Sequence<URL>, home: URL) -> String {
        let homePath = stripTrailingSlash(home.standardizedFileURL.path)
        return sortedPaths(urls).map { abbreviated($0, homePath: homePath) }.joined(separator: "\n")
    }

    static func abbreviated(_ path: String, homePath: String) -> String {
        let home = stripTrailingSlash(homePath)
        guard !home.isEmpty, home != "/" else { return path }
        let item = stripTrailingSlash(path)
        if item == home { return "~" }
        let prefix = home + "/"
        guard item.hasPrefix(prefix) else { return path }
        return "~/" + item.dropFirst(prefix.count)
    }

    private static func sortedPaths(_ urls: some Sequence<URL>) -> [String] {
        urls.map(\.path).sorted()
    }

    private static func name(for path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }

    private static func stripTrailingSlash(_ path: String) -> String {
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
