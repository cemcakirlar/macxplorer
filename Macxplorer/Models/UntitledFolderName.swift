import Foundation

enum UntitledFolderName {
    static let base = "untitled folder"

    static func next(existing names: [String], caseSensitive: Bool) -> String {
        if !taken(base, in: names, caseSensitive: caseSensitive) {
            return base
        }
        var index = 2
        while taken(numbered(index), in: names, caseSensitive: caseSensitive) {
            index += 1
        }
        return numbered(index)
    }

    private static func numbered(_ index: Int) -> String {
        "\(base) \(index)"
    }

    private static func taken(_ name: String, in names: [String], caseSensitive: Bool) -> Bool {
        names.contains { existing in
            if caseSensitive {
                return existing == name
            }
            return existing.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}
