import Foundation

struct TransferWrite: Equatable, Sendable {
    var url: URL
    /// Set when a same-volume move took the item from this URL.
    var movedFrom: URL?
    /// The item that was already at `url` and went to the Trash before the write.
    var displaced: TrashedItem?
    /// Set when a move copied onto another volume and then trashed the source.
    var crossVolumeSource: TrashedItem?
}

enum FileTransferError: Error, Equatable, Sendable {
    case nameTaken(String)
    case trashFailed(String)
    case insideItself(String)
    /// The copy is at `write.url`. The source is still in place.
    case copiedButSourceRemained(TransferWrite)
}

enum FileTransfer {
    struct Operations: Sendable {
        var copy: @Sendable (URL, URL) throws -> Void
        var move: @Sendable (URL, URL) throws -> Void
        var trash: @Sendable (URL) throws -> URL
        var exists: @Sendable (URL) -> Bool
        var sameVolume: @Sendable (URL, URL) -> Bool

        static let live = Operations(
            copy: { source, destination in
                try FileManager.default.copyItem(at: source, to: destination)
            },
            move: { source, destination in
                try FileManager.default.moveItem(at: source, to: destination)
            },
            trash: { url in
                var resulting: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                guard let trashed = resulting as URL? else {
                    throw CocoaError(.fileWriteUnknown)
                }
                return trashed
            },
            exists: { url in
                FileManager.default.fileExists(atPath: url.path)
            },
            sameVolume: { source, destination in
                volumesMatch(source, destination)
            }
        )
    }

    /// Copies or moves `source` to `destination`. Replace trashes the occupant first.
    /// A failed trash leaves the occupant in place and writes nothing.
    static func perform(
        from source: URL,
        to destination: URL,
        moving: Bool,
        replacing: Bool,
        operations: Operations = .live
    ) throws -> TransferWrite {
        let parent = destination.deletingLastPathComponent()
        if TransferNames.destinationIsInside(source, destinationDirectory: parent) {
            throw FileTransferError.insideItself(source.lastPathComponent)
        }
        let sameVolume = operations.sameVolume(source, parent)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        let outcome = Outcome()
        if moving && sameVolume {
            coordinator.coordinate(
                writingItemAt: source,
                options: .forMoving,
                writingItemAt: destination,
                options: .forReplacing,
                error: &coordinationError
            ) { sourceURL, destinationURL in
                outcome.result = Result {
                    try write(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        source: source,
                        destination: destination,
                        moving: true,
                        sameVolume: true,
                        replacing: replacing,
                        operations: operations
                    )
                }
            }
        } else {
            coordinator.coordinate(
                readingItemAt: source,
                options: [],
                writingItemAt: destination,
                options: .forReplacing,
                error: &coordinationError
            ) { sourceURL, destinationURL in
                outcome.result = Result {
                    try write(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        source: source,
                        destination: destination,
                        moving: moving,
                        sameVolume: sameVolume,
                        replacing: replacing,
                        operations: operations
                    )
                }
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

    private static func write(
        sourceURL: URL,
        destinationURL: URL,
        source: URL,
        destination: URL,
        moving: Bool,
        sameVolume: Bool,
        replacing: Bool,
        operations: Operations
    ) throws -> TransferWrite {
        let target = destinationURL
        var displaced: TrashedItem?
        if operations.exists(target) {
            if !replacing {
                throw FileTransferError.nameTaken(destination.lastPathComponent)
            }
            do {
                let trashed = try operations.trash(target)
                displaced = TrashedItem(original: destination, trashed: trashed)
            } catch {
                throw FileTransferError.trashFailed(destination.lastPathComponent)
            }
        }
        do {
            if moving && sameVolume {
                try operations.move(sourceURL, target)
                return TransferWrite(url: destination, movedFrom: source, displaced: displaced)
            }
            try operations.copy(sourceURL, target)
        } catch {
            if let displaced {
                try? operations.move(displaced.trashed, target)
            }
            if operations.exists(target) && displaced == nil {
                throw FileTransferError.nameTaken(destination.lastPathComponent)
            }
            throw error
        }
        guard moving, !sameVolume else {
            return TransferWrite(url: destination, displaced: displaced)
        }
        do {
            let trashed = try operations.trash(sourceURL)
            return TransferWrite(
                url: destination,
                displaced: displaced,
                crossVolumeSource: TrashedItem(original: source, trashed: trashed)
            )
        } catch {
            throw FileTransferError.copiedButSourceRemained(
                TransferWrite(url: destination, displaced: displaced)
            )
        }
    }

    private static func volumesMatch(_ source: URL, _ destination: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.volumeIdentifierKey]
        guard
            let left = try? source.resourceValues(forKeys: keys).volumeIdentifier as? NSObject,
            let right = try? destination.resourceValues(forKeys: keys).volumeIdentifier
        else {
            return false
        }
        return left.isEqual(right)
    }

    private final class Outcome: @unchecked Sendable {
        var result: Result<TransferWrite, Error>?
    }
}
