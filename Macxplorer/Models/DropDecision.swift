import Foundation

enum DropTargetKind: Equatable, Sendable {
    /// Open folder, a folder row, or a favorite whose folder is still there.
    case folder(URL)
    /// A file row. Nothing is written.
    case file
    /// A favorite whose folder is gone. Nothing is written.
    case missing
}

enum DropItemDecision: Equatable, Sendable {
    case copy
    case move
    case refuse
}

enum DropDecision {
    /// Option always copies. Otherwise the same disk moves and another disk copies.
    /// A file row, a missing favorite, and a drop onto the item or into its subfolder write nothing.
    static func item(
        source: URL,
        target: DropTargetKind,
        sameVolume: Bool,
        optionPressed: Bool
    ) -> DropItemDecision {
        guard case .folder(let destination) = target else { return .refuse }
        if TransferNames.destinationIsInside(source, destinationDirectory: destination) {
            return .refuse
        }
        if optionPressed || !sameVolume {
            return .copy
        }
        return .move
    }
}
