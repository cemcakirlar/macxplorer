import Foundation

/// Keeps the list selection across one folder change, and only a change into the folder it was armed for.
struct SelectionHold: Equatable {
    private(set) var target: String?

    mutating func arm(for url: URL) {
        target = url.directoryKey.path
    }

    /// Always disarms.
    mutating func consume(for url: URL?) -> Bool {
        defer { target = nil }
        guard let target, let url else { return false }
        return target == url.directoryKey.path
    }
}
