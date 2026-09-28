import Foundation

enum RenameRejection: Equatable {
    case invalidCharacters(String)
    case reservedName(String)
    case tooLong(String)
    case nameTaken(String)

    var title: String {
        switch self {
        case .invalidCharacters, .reservedName:
            "Invalid Name"
        case .tooLong:
            "Name Too Long"
        case .nameTaken:
            "Name Already Taken"
        }
    }

    var message: String {
        switch self {
        case .invalidCharacters(let name):
            "The name “\(name)” can’t contain a colon (:) or a slash (/)."
        case .reservedName(let name):
            "The name “\(name)” can’t be used."
        case .tooLong:
            "The name is too long. Use a name with 255 bytes or fewer."
        case .nameTaken(let name):
            "The name “\(name)” is already taken. Please choose a different name."
        }
    }
}

enum RenameDecision: Equatable {
    case cancel
    case rejected(RenameRejection)
    case confirmExtension(from: String, to: String)
    case commit(String)
}

struct RenameExtensionPrompt: Equatable {
    var from: String
    var to: String

    var title: String {
        "Are you sure you want to change the extension from “\(dotted(from))” to “\(dotted(to))”?"
    }

    var keepButton: String {
        from.isEmpty ? "Keep" : "Keep .\(from)"
    }

    var useButton: String {
        to.isEmpty ? "Use" : "Use .\(to)"
    }

    private func dotted(_ extensionName: String) -> String {
        extensionName.isEmpty ? "" : ".\(extensionName)"
    }
}

enum RenameName {
    static let maximumUTF8Bytes = 255

    static func decision(
        currentName: String,
        proposedName: String,
        isFolder: Bool,
        siblingNames: [String],
        caseSensitive: Bool,
        extensionChangeConfirmed: Bool
    ) -> RenameDecision {
        if proposedName.isEmpty || proposedName == currentName {
            return .cancel
        }
        if proposedName.contains("/") || proposedName.contains(":") {
            return .rejected(.invalidCharacters(proposedName))
        }
        if proposedName == "." || proposedName == ".." {
            return .rejected(.reservedName(proposedName))
        }
        if proposedName.utf8.count > maximumUTF8Bytes {
            return .rejected(.tooLong(proposedName))
        }
        if !extensionChangeConfirmed,
           let change = extensionChange(from: currentName, to: proposedName, isFolder: isFolder) {
            return .confirmExtension(from: change.from, to: change.to)
        }
        if nameIsTaken(
            proposedName,
            currentName: currentName,
            siblingNames: siblingNames,
            caseSensitive: caseSensitive
        ) {
            return .rejected(.nameTaken(proposedName))
        }
        return .commit(proposedName)
    }

    static func filtering(_ text: String) -> String {
        String(text.filter { $0 != "/" && $0 != ":" })
    }

    /// The portion of `name` the rename field selects. Folders and single-dot names such as `.gitignore` select everything.
    static func selectedPrefix(in name: String, isFolder: Bool) -> String {
        if isFolder || isSingleDotHiddenName(name) {
            return name
        }
        let base = (name as NSString).deletingPathExtension
        if base.isEmpty || base == name {
            return name
        }
        return base
    }

    static func nameByRestoringExtension(_ name: String, extension restored: String) -> String {
        let base = (name as NSString).deletingPathExtension
        let stem = base.isEmpty ? name : base
        if restored.isEmpty {
            return stem
        }
        return "\(stem).\(restored)"
    }

    static func extensionChange(
        from currentName: String,
        to proposedName: String,
        isFolder: Bool
    ) -> (from: String, to: String)? {
        guard !isFolder else { return nil }
        let current = trackedExtension(currentName)
        let proposed = trackedExtension(proposedName)
        guard current != proposed else { return nil }
        return (current, proposed)
    }

    static func nameIsTaken(
        _ proposed: String,
        currentName: String,
        siblingNames: [String],
        caseSensitive: Bool
    ) -> Bool {
        siblingNames.contains { sibling in
            sameName(sibling, proposed, caseSensitive: caseSensitive)
                && !sameName(sibling, currentName, caseSensitive: caseSensitive)
        }
    }

    private static func trackedExtension(_ name: String) -> String {
        if isSingleDotHiddenName(name) {
            return ""
        }
        return (name as NSString).pathExtension
    }

    private static func isSingleDotHiddenName(_ name: String) -> Bool {
        name.count > 1 && name.hasPrefix(".") && !name.dropFirst().contains(".")
    }

    private static func sameName(_ lhs: String, _ rhs: String, caseSensitive: Bool) -> Bool {
        if caseSensitive {
            return lhs == rhs
        }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

enum RenamedPath {
    /// Rewrites `path` when it is `oldPath` or a descendant. A neighboring prefix such as `/Users/ab` stays put.
    static func rewriting(_ path: String, from oldPath: String, to newPath: String) -> String {
        let current = Favorites.key(forPath: path)
        let old = Favorites.key(forPath: oldPath)
        let new = Favorites.key(forPath: newPath)
        if current == old {
            return new
        }
        guard old != "/" else { return path }
        let prefix = old + "/"
        guard current.hasPrefix(prefix) else { return path }
        let suffix = current.dropFirst(prefix.count)
        if new == "/" {
            return "/" + suffix
        }
        return new + "/" + suffix
    }

    static func url(_ url: URL, from oldURL: URL, to newURL: URL) -> URL {
        let rewritten = rewriting(url.path, from: oldURL.path, to: newURL.path)
        if rewritten == url.path {
            return url
        }
        return URL(fileURLWithPath: rewritten, isDirectory: url.hasDirectoryPath)
    }
}
