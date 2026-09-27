import Darwin
import Foundation

enum FileSystemService {
    /// Reads one directory off the main actor. `FileManager` calls are synchronous,
    /// so an `async` function that stayed on the caller would still hitch the UI.
    static func listDirectory(at url: URL, showHidden: Bool) async throws -> [FileEntry] {
        let target = url
        let includeHidden = showHidden
        let work = Task.detached(priority: .userInitiated) {
            try readDirectory(at: target, showHidden: includeHidden)
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }

    /// One directory level. Returns on the first listable subfolder. `nil` if cancelled.
    static func containsListableFolder(at url: URL, showHidden: Bool) async -> Bool? {
        let target = url
        let includeHidden = showHidden
        let work = Task.detached(priority: .utility) {
            directoryContainsFolder(at: target, showHidden: includeHidden)
        }
        return await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
    }

    static func sortedForDisplay(_ entries: [FileEntry]) -> [FileEntry] {
        FileListOrder.sorted(entries)
    }

    /// Unreadable folders are omitted. The sidebar cannot open them, and listing
    /// their contents only produces a permission error.
    static func shouldList(opensAsFolder: Bool, isReadable: Bool?) -> Bool {
        !(opensAsFolder && isReadable == false)
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isPackageKey,
        .isReadableKey,
        .isHiddenKey,
        .localizedNameKey,
        .contentModificationDateKey,
        .fileSizeKey,
        .localizedTypeDescriptionKey,
    ]

    private static func readDirectory(at url: URL, showHidden: Bool) throws -> [FileEntry] {
        try Task.checkCancellation()
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: options
        )
        let keySet = Set(resourceKeys)
        var entries: [FileEntry] = []
        entries.reserveCapacity(urls.count)

        var examined = 0
        for itemURL in urls {
            examined += 1
            if examined.isMultiple(of: 64) {
                try Task.checkCancellation()
            }
            let values = try? itemURL.resourceValues(forKeys: keySet)
            let name = values?.localizedName ?? itemURL.lastPathComponent
            if name.isEmpty { continue }
            if !showHidden && isHiddenEntry(name: name, isHidden: values?.isHidden) {
                continue
            }

            let isDirectory = values?.isDirectory ?? false
            let isPackage = values?.isPackage ?? false
            let opensAsFolder = isDirectory && !isPackage
            if !shouldList(opensAsFolder: opensAsFolder, isReadable: values?.isReadable) {
                continue
            }
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

    /// Reads directory entries only. `d_type` skips files without a per-file stat.
    /// A folder of files and no subfolders still walks every name; it does not stat them.
    private static func directoryContainsFolder(at url: URL, showHidden: Bool) -> Bool? {
        guard let dir = opendir(url.path) else { return false }
        defer { closedir(dir) }
        while let entry = readdir(dir) {
            if Task.isCancelled { return nil }
            let name = directoryEntryName(entry)
            if name.isEmpty || name == "." || name == ".." { continue }
            if !showHidden && name.hasPrefix(".") { continue }
            let type = entry.pointee.d_type
            if type != UInt8(DT_DIR) && type != UInt8(DT_UNKNOWN) { continue }
            let child = url.appendingPathComponent(name, isDirectory: true)
            if isListableChildFolder(child, showHidden: showHidden) {
                return true
            }
        }
        return false
    }

    private static func directoryEntryName(_ entry: UnsafeMutablePointer<dirent>) -> String {
        let namlen = Int(entry.pointee.d_namlen)
        return withUnsafePointer(to: &entry.pointee.d_name) { namePtr in
            namePtr.withMemoryRebound(to: UInt8.self, capacity: namlen) { rebound in
                String(decoding: UnsafeBufferPointer(start: rebound, count: namlen), as: UTF8.self)
            }
        }
    }

    private static func isListableChildFolder(_ url: URL, showHidden: Bool) -> Bool {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isReadableKey, .isHiddenKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        if !showHidden && isHiddenEntry(name: url.lastPathComponent, isHidden: values.isHidden) {
            return false
        }
        let opensAsFolder = (values.isDirectory ?? false) && values.isPackage != true
        return opensAsFolder && shouldList(opensAsFolder: true, isReadable: values.isReadable)
    }

    private static func isHiddenEntry(name: String, isHidden: Bool?) -> Bool {
        isHidden == true || name.hasPrefix(".")
    }
}
