import Foundation

@MainActor
enum MainActorUndo {
    static func register<Target: AnyObject>(
        undoManager: UndoManager?,
        actionName: String,
        target: Target,
        handler: @escaping @MainActor (Target) async -> Void
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: target) { target in
            Task { @MainActor in
                await handler(target)
            }
        }
        undoManager.setActionName(actionName)
    }
}

@MainActor
final class RenameUndoRelay {
    var perform: ((URL, String) async -> Bool)?

    func register(undoManager: UndoManager?, from oldURL: URL, to newURL: URL) {
        MainActorUndo.register(undoManager: undoManager, actionName: "Rename", target: self) { relay in
            let previousName = oldURL.lastPathComponent
            let currentURL = newURL
            let succeeded = await relay.perform?(currentURL, previousName) ?? false
            if succeeded {
                relay.register(undoManager: undoManager, from: currentURL, to: oldURL)
            } else {
                relay.register(undoManager: undoManager, from: oldURL, to: newURL)
            }
        }
    }
}

@MainActor
final class TrashUndoRelay {
    /// Puts items back. Returns the ones that stayed in the Trash.
    var putBack: (([TrashedItem]) async -> [TrashedItem])?

    func register(undoManager: UndoManager?, items: [TrashedItem]) {
        guard !items.isEmpty else { return }
        MainActorUndo.register(undoManager: undoManager, actionName: "Move to Trash", target: self) { relay in
            let remaining = await relay.putBack?(items) ?? items
            if !remaining.isEmpty {
                relay.register(undoManager: undoManager, items: remaining)
            }
        }
    }
}

@MainActor
final class NewFolderUndoRelay {
    var undo: ((URL, CreatedFolderIdentity) async -> Void)?

    func register(undoManager: UndoManager?, folder: URL, identity: CreatedFolderIdentity) {
        MainActorUndo.register(undoManager: undoManager, actionName: "New Folder", target: self) { relay in
            await relay.undo?(folder, identity)
        }
    }
}

final class CreatedFolderIdentity: @unchecked Sendable {
    let value: NSObject?

    init(_ value: NSObject?) {
        self.value = value
    }

    static func of(_ url: URL) -> CreatedFolderIdentity {
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey])
        return CreatedFolderIdentity(values?.fileResourceIdentifier as? NSObject)
    }

    /// `true` while `url` still holds the item this identity came from. With no identity, the path alone decides.
    func stillIdentifies(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let value else { return true }
        guard let current = CreatedFolderIdentity.of(url).value else { return false }
        return current.isEqual(value)
    }
}

struct TransferUndoItem: Sendable {
    var write: TransferWrite
    var identity: CreatedFolderIdentity
}

@MainActor
final class TransferUndoRelay {
    var undo: (([TransferUndoItem]) async -> [TransferUndoItem])?

    func register(undoManager: UndoManager?, items: [TransferUndoItem], actionName: String) {
        guard !items.isEmpty else { return }
        MainActorUndo.register(undoManager: undoManager, actionName: actionName, target: self) { relay in
            let remaining = await relay.undo?(items) ?? items
            if !remaining.isEmpty {
                relay.register(undoManager: undoManager, items: remaining, actionName: actionName)
            }
        }
    }
}
