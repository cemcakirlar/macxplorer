import Foundation

enum FileNameFilter {
    /// Blank or whitespace-only query returns `entries` unchanged.
    static func filtered(_ entries: [FileEntry], query: String) -> [FileEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.name.localizedStandardContains(trimmed) }
    }

    /// First entry whose name has `buffer` as a case/diacritic-insensitive prefix.
    static func firstPrefixMatch(in entries: [FileEntry], buffer: String) -> FileEntry? {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return entries.first { entry in
            entry.name.range(
                of: trimmed,
                options: [.anchored, .caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }
}
