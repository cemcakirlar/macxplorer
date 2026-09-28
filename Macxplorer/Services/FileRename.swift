import Foundation

enum FileRenameError: Error, Equatable, Sendable {
    case nameTaken(String)
}

enum FileRename {
    struct Move: Sendable {
        var perform: @Sendable (URL, URL) throws -> Void

        static let live = Move { source, destination in
            try FileManager.default.moveItem(at: source, to: destination)
        }
    }

    static func apply(at url: URL, to newName: String) throws -> URL {
        try apply(at: url, to: newName, moves: .live)
    }

    static func apply(at url: URL, to newName: String, moves: Move) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        let outcome = Outcome()
        coordinator.coordinate(writingItemAt: url, options: .forMoving, error: &coordinationError) { writingURL in
            outcome.result = Result {
                try renameCoordinated(writingURL, to: newName, moves: moves)
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result = outcome.result else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try result.get()
    }

    private static func renameCoordinated(_ writingURL: URL, to newName: String, moves: Move) throws -> URL {
        let destination = writingURL
            .deletingLastPathComponent()
            .appendingPathComponent(newName, isDirectory: writingURL.hasDirectoryPath)
        if blocksRename(from: writingURL, to: destination) {
            throw FileRenameError.nameTaken(newName)
        }
        do {
            if isSymbolicLink(writingURL) {
                try moves.perform(writingURL, destination)
                return destination
            }
            if isCaseOnlyRename(from: writingURL.lastPathComponent, to: newName) {
                try moves.perform(writingURL, destination)
                return destination
            }
            var mutable = writingURL
            var values = URLResourceValues()
            values.name = newName
            try mutable.setResourceValues(values)
            return destination
        } catch let error as FileRenameError {
            throw error
        } catch {
            if isExistingItem(error) {
                throw FileRenameError.nameTaken(newName)
            }
            throw error
        }
    }

    private static func blocksRename(from source: URL, to destination: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: destination.path) else { return false }
        if sameIdentity(source, destination) == true {
            return false
        }
        let caseOnly = source.lastPathComponent != destination.lastPathComponent
            && source.lastPathComponent.caseInsensitiveCompare(destination.lastPathComponent) == .orderedSame
        let caseSensitive = (try? source.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames) == true
        if caseOnly && !caseSensitive {
            return false
        }
        return true
    }

    private static func sameIdentity(_ source: URL, _ destination: URL) -> Bool? {
        let key = URLResourceKey.fileResourceIdentifierKey
        guard
            let left = try? source.resourceValues(forKeys: [key]).fileResourceIdentifier,
            let right = try? destination.resourceValues(forKeys: [key]).fileResourceIdentifier
        else {
            return nil
        }
        return (left as AnyObject).isEqual(right)
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func isCaseOnlyRename(from current: String, to proposed: String) -> Bool {
        current != proposed && current.caseInsensitiveCompare(proposed) == .orderedSame
    }

    private static func isExistingItem(_ error: Error) -> Bool {
        let cocoa = error as? CocoaError
        return cocoa?.code == .fileWriteFileExists || cocoa?.code == .fileWriteInvalidFileName
    }

    private final class Outcome: @unchecked Sendable {
        var result: Result<URL, Error>?
    }
}
