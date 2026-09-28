import Foundation

enum NewFolder {
    static func create(in parent: URL) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        let outcome = Outcome()
        coordinator.coordinate(writingItemAt: parent, options: .forMerging, error: &coordinationError) { writingURL in
            outcome.result = Result { try createCoordinated(in: writingURL) }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result = outcome.result else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try result.get()
    }

    private static func createCoordinated(in parent: URL) throws -> URL {
        let caseSensitive = (try? parent.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames) == true
        var blocked = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
        while true {
            let name = UntitledFolderName.next(existing: blocked, caseSensitive: caseSensitive)
            if taken(name, in: blocked, caseSensitive: caseSensitive) {
                throw CocoaError(.fileWriteFileExists)
            }
            let destination = parent.appendingPathComponent(name, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
                return destination
            } catch {
                let existsNow = FileManager.default.fileExists(atPath: destination.path)
                if existsNow || isExistingItem(error) {
                    blocked.append(name)
                    continue
                }
                throw error
            }
        }
    }

    private static func taken(_ name: String, in names: [String], caseSensitive: Bool) -> Bool {
        names.contains { existing in
            if caseSensitive {
                return existing == name
            }
            return existing.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    private static func isExistingItem(_ error: Error) -> Bool {
        (error as? CocoaError)?.code == .fileWriteFileExists
    }

    private final class Outcome: @unchecked Sendable {
        var result: Result<URL, Error>?
    }
}
