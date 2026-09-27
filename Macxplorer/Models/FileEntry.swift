import Foundation

struct FileEntry: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let modified: Date?
    let size: Int64?
    let kind: String

    var id: URL { url }

    var opensAsFolder: Bool {
        isDirectory && !isPackage
    }

    /// Header identity for the date column. Display order uses `modified`.
    var modifiedColumn: Date { modified ?? .distantPast }

    /// Header identity for the size column. Display order uses `size`.
    var sizeColumn: Int64 { size ?? 0 }
}

extension URL {
    /// Stable folder identity: standardized path, no trailing slash, except `/`.
    var directoryKey: URL {
        let standardized = standardizedFileURL
        let path = standardized.path
        if path.isEmpty || path == "/" {
            return URL(fileURLWithPath: "/", isDirectory: true)
        }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        return URL(fileURLWithPath: trimmed, isDirectory: true)
    }
}
