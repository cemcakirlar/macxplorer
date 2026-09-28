import Foundation

struct TrashedItem: Equatable, Sendable {
    var original: URL
    var trashed: URL
}

enum FileTrashError: Error, Equatable, Sendable {
    case nameTaken(String)
}

enum FileTrash {
    struct Operations: Sendable {
        var trash: @Sendable (URL) throws -> URL
        var move: @Sendable (URL, URL) throws -> Void
        var exists: @Sendable (URL) -> Bool

        static let live = Operations(
            trash: { url in
                var resulting: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                guard let trashed = resulting as URL? else {
                    throw CocoaError(.fileWriteUnknown)
                }
                return trashed
            },
            move: { source, destination in
                try FileManager.default.moveItem(at: source, to: destination)
            },
            exists: { url in
                FileManager.default.fileExists(atPath: url.path)
            }
        )
    }

    static func trash(at url: URL, operations: Operations = .live) throws -> URL {
        try coordinate(url, options: .forDeleting) { writingURL in
            try operations.trash(writingURL)
        }
    }

    static func putBack(trashed: URL, to original: URL, operations: Operations = .live) throws {
        _ = try coordinate(trashed, options: .forMoving) { writingURL in
            if operations.exists(original) {
                throw FileTrashError.nameTaken(original.lastPathComponent)
            }
            do {
                try operations.move(writingURL, original)
            } catch {
                if operations.exists(original) || isExistingItem(error) {
                    throw FileTrashError.nameTaken(original.lastPathComponent)
                }
                throw error
            }
            return original
        }
    }

    private static func coordinate(
        _ url: URL,
        options: NSFileCoordinator.WritingOptions,
        body: (URL) throws -> URL
    ) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        let outcome = Outcome()
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { writingURL in
            outcome.result = Result { try body(writingURL) }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result = outcome.result else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try result.get()
    }

    private static func isExistingItem(_ error: Error) -> Bool {
        (error as? CocoaError)?.code == .fileWriteFileExists
    }

    private final class Outcome: @unchecked Sendable {
        var result: Result<URL, Error>?
    }
}
