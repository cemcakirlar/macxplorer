import Foundation

/// Carries a result out of an `NSFileCoordinator` block, which runs synchronously on the calling thread.
final class CoordinatedOutcome<Value>: @unchecked Sendable {
    var result: Result<Value, Error>?
}
