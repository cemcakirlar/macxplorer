import Foundation

enum TransferChoice: Equatable, Sendable {
    case stop
    case keepBoth
    case replace
}

enum TransferDecision: Equatable, Sendable {
    /// Write this name. An existing different item stays put.
    case write(String)
    /// Move the existing item to the Trash, then write this name.
    case replace(String)
    /// The name is taken and the batch has not chosen yet.
    case ask(String)
    /// This item and every later item stay unwritten.
    case stop
}

enum TransferNames {
    static func keepBothName(for name: String, existing: [String], caseSensitive: Bool) -> String {
        let parts = stemAndExtension(name)
        let first = joined(parts, suffix: " copy")
        if !taken(first, in: existing, caseSensitive: caseSensitive) {
            return first
        }
        var index = 2
        while taken(joined(parts, suffix: " copy \(index)"), in: existing, caseSensitive: caseSensitive) {
            index += 1
        }
        return joined(parts, suffix: " copy \(index)")
    }

    /// `choice` applies to this conflict and, once set, to every later item.
    /// A free name still writes, except after Stop, which writes nothing further.
    static func decision(
        name: String,
        existing: [String],
        caseSensitive: Bool,
        choice: TransferChoice?
    ) -> TransferDecision {
        if choice == .stop {
            return .stop
        }
        if !taken(name, in: existing, caseSensitive: caseSensitive) {
            return .write(name)
        }
        switch choice {
        case nil:
            return .ask(name)
        case .stop:
            return .stop
        case .keepBoth:
            return .write(keepBothName(for: name, existing: existing, caseSensitive: caseSensitive))
        case .replace:
            return .replace(name)
        }
    }

    /// The destination directory is the source itself or a folder inside it.
    static func destinationIsInside(_ source: URL, destinationDirectory: URL) -> Bool {
        let sourceKey = Favorites.key(for: source)
        let destinationKey = Favorites.key(for: destinationDirectory)
        if destinationKey == sourceKey {
            return true
        }
        guard sourceKey != "/" else { return true }
        return destinationKey.hasPrefix(sourceKey + "/")
    }

    static func sameItem(_ left: URL, _ right: URL, caseSensitive: Bool) -> Bool {
        let leftKey = Favorites.key(for: left)
        let rightKey = Favorites.key(for: right)
        if caseSensitive {
            return leftKey == rightKey
        }
        return leftKey.caseInsensitiveCompare(rightKey) == .orderedSame
    }

    private static func stemAndExtension(_ name: String) -> (stem: String, ext: String) {
        let fileName = name as NSString
        let ext = fileName.pathExtension
        let stem = fileName.deletingPathExtension
        if ext.isEmpty || stem.isEmpty {
            return (name, "")
        }
        return (stem, ext)
    }

    private static func joined(_ parts: (stem: String, ext: String), suffix: String) -> String {
        if parts.ext.isEmpty {
            return parts.stem + suffix
        }
        return "\(parts.stem)\(suffix).\(parts.ext)"
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
