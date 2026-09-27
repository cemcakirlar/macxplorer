import Foundation

enum FileSystemService {
    /// Reads one directory off the main actor. `FileManager` calls are synchronous,
    /// so an `async` function that stayed on the caller would still hitch the UI.
    static func listDirectory(at url: URL, showHidden: Bool) async throws -> [FileEntry] {
        let target = url
        let includeHidden = showHidden
        return try await Task.detached(priority: .userInitiated) {
            try readDirectory(at: target, showHidden: includeHidden)
        }.value
    }

    static func sortedForDisplay(_ entries: [FileEntry]) -> [FileEntry] {
        entries.sorted { lhs, rhs in
            if lhs.opensAsFolder != rhs.opensAsFolder {
                return lhs.opensAsFolder
            }
            let order = lhs.name.localizedStandardCompare(rhs.name)
            if order == .orderedSame {
                return lhs.url.path.localizedStandardCompare(rhs.url.path) == .orderedAscending
            }
            return order == .orderedAscending
        }
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isPackageKey,
        .isHiddenKey,
        .localizedNameKey,
        .contentModificationDateKey,
        .fileSizeKey,
        .localizedTypeDescriptionKey,
    ]

    private static func readDirectory(at url: URL, showHidden: Bool) throws -> [FileEntry] {
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: options
        )
        let keySet = Set(resourceKeys)
        var entries: [FileEntry] = []
        entries.reserveCapacity(urls.count)

        for itemURL in urls {
            let values = try? itemURL.resourceValues(forKeys: keySet)
            let name = values?.localizedName ?? itemURL.lastPathComponent
            if name.isEmpty { continue }
            if !showHidden && (values?.isHidden == true || name.hasPrefix(".")) {
                continue
            }

            let isDirectory = values?.isDirectory ?? false
            let isPackage = values?.isPackage ?? false
            let opensAsFolder = isDirectory && !isPackage
            let size = opensAsFolder ? nil : values?.fileSize.map(Int64.init)
            let kind = values?.localizedTypeDescription ?? (opensAsFolder ? "Folder" : "Document")

            entries.append(
                FileEntry(
                    url: itemURL,
                    name: name,
                    isDirectory: isDirectory,
                    isPackage: isPackage,
                    modified: values?.contentModificationDate,
                    size: size,
                    kind: kind
                )
            )
        }

        return sortedForDisplay(entries)
    }
}
