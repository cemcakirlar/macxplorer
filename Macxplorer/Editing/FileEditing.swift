import AppKit
import Observation
import SwiftUI

enum FileAlertCopy {
    static func nameTaken(_ name: String, detail: String? = nil) -> String {
        if let detail {
            return "The name “\(name)” is already taken. \(detail)"
        }
        return "The name “\(name)” is already taken."
    }

    static func trashConfirmationTitle(_ names: [String]) -> String {
        if names.count == 1, let name = names.first {
            return "Move “\(name)” to the Trash?"
        }
        return "Move \(names.count) items to the Trash?"
    }
}

/// The editing state the views bind to. File work goes to the rename, trash, and transfer coordinators.
@MainActor
@Observable
final class FileEditing {
    var listSelection = Set<URL>()
    var quickLookURL: URL?
    let alerts = AlertPresenter()
    var renameSession: RenameSession?
    var extensionPrompt: RenameExtensionPrompt?
    var renameRefocusID = 0
    var renameAcceptsCommit = false
    var pasteboardToken = 0
    var isTransferring = false

    @ObservationIgnored private var model: BrowserModel?
    @ObservationIgnored var undoManager: UndoManager?
    @ObservationIgnored private let renameUndo = RenameUndoRelay()
    @ObservationIgnored private let trashUndo = TrashUndoRelay()
    @ObservationIgnored private let newFolderUndo = NewFolderUndoRelay()
    @ObservationIgnored private let transferUndo = TransferUndoRelay()

    private var renames: RenameCoordinator? {
        model.map { RenameCoordinator(model: $0, alerts: alerts) }
    }

    private var trashes: TrashCoordinator? {
        model.map { TrashCoordinator(model: $0, alerts: alerts) }
    }

    private var transfers: TransferCoordinator? {
        model.map { TransferCoordinator(model: $0, alerts: alerts) }
    }

    var draft: Binding<String> {
        Binding(
            get: { self.renameSession?.draft ?? "" },
            set: { newValue in
                let filtered = RenameName.filtering(newValue)
                if self.renameSession?.draft != filtered {
                    self.renameAcceptsCommit = true
                }
                self.renameSession?.draft = filtered
            }
        )
    }

    func bind(model: BrowserModel, undoManager: UndoManager?) {
        self.model = model
        self.undoManager = undoManager
        installUndo()
    }

    func beginRename(_ url: URL) {
        guard renameSession == nil, let model else { return }
        guard !ProtectedFolders.contains(url) else {
            NSSound.beep()
            return
        }
        let isFolder: Bool
        if let entry = model.entries.first(where: { $0.url.path == url.path }) {
            isFolder = entry.opensAsFolder
        } else {
            isFolder = true
        }
        let resolved = isFolder ? url.directoryKey : url
        renameAcceptsCommit = true
        renameSession = RenameSession(
            url: resolved,
            isFolder: isFolder,
            draft: resolved.lastPathComponent
        )
    }

    func cancelRename() {
        renameAcceptsCommit = false
        extensionPrompt = nil
        renameSession = nil
    }

    func commitRename() {
        guard renameAcceptsCommit, let session = renameSession, let renames else { return }
        renameAcceptsCommit = false
        switch renames.decision(for: session) {
        case .cancel:
            renameSession = nil
        case .rejected(let rejection):
            alerts.show(ActionAlert(title: rejection.title, message: rejection.message))
        case .confirmExtension(let from, let to):
            extensionPrompt = RenameExtensionPrompt(from: from, to: to)
        case .commit(let name):
            let url = session.url
            Task {
                let succeeded = await performRename(of: url, to: name, registersUndo: true)
                if succeeded {
                    renameSession = nil
                } else {
                    renameAcceptsCommit = true
                    renameRefocusID += 1
                }
            }
        }
    }

    func keepCurrentExtension(_ prompt: RenameExtensionPrompt?) {
        guard var session = renameSession, let prompt else { return }
        session.draft = RenameName.nameByRestoringExtension(session.draft, extension: prompt.from)
        session.extensionChangeConfirmed = true
        renameSession = session
        extensionPrompt = nil
        renameAcceptsCommit = true
        commitRename()
    }

    func useProposedExtension() {
        guard var session = renameSession else { return }
        session.extensionChangeConfirmed = true
        renameSession = session
        extensionPrompt = nil
        renameAcceptsCommit = true
        commitRename()
    }

    func moveToTrash(_ urls: [URL]) {
        guard !urls.isEmpty, let model, let trashes else { return }
        Task {
            guard let run = await trashes.trash(urls) else { return }
            if !run.moved.isEmpty {
                let roots = run.moved.map(\.original)
                let rootPaths = roots.map(\.path)
                listSelection = listSelection.filter { !TrashTargets.affects($0.path, trashed: rootPaths) }
                if let quickLookURL, TrashTargets.affects(quickLookURL.path, trashed: rootPaths) {
                    self.quickLookURL = nil
                }
                if let session = renameSession, TrashTargets.affects(session.url.path, trashed: rootPaths) {
                    renameSession = nil
                }
                await model.applyTrashed(roots)
                installUndo()
                trashUndo.register(undoManager: undoManager, items: run.moved)
                appLogger.info("Moved \(run.moved.count, privacy: .public) item(s) to the Trash")
            }
            trashes.report(run.failures)
        }
    }

    func createNewFolder() {
        guard let model, let parent = model.selectedURL else { return }
        Task {
            do {
                let created = try await Task.detached {
                    try NewFolder.create(in: parent)
                }.value
                let listed = await model.refreshedEntry(matching: created) ?? created
                cancelRename()
                listSelection = [listed]
                let folder = listed
                Task { @MainActor in
                    beginRename(folder)
                }
                installUndo()
                newFolderUndo.register(
                    undoManager: undoManager,
                    folder: created,
                    identity: .of(created)
                )
                appLogger.info("Created folder at \(created.path, privacy: .public)")
            } catch {
                alerts.show(ActionAlert(title: "Can't Create Folder", message: error.localizedDescription))
                appLogger.info("Failed to create folder in \(parent.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func pasteFromClipboard(moving: Bool) {
        guard renameSession == nil, !isTransferring, let model, let destination = model.selectedURL else { return }
        let sources = FilePasteboard.read()
        guard !sources.isEmpty else { return }
        startTransfer(sources.map { PendingTransfer(url: $0, moving: moving) }, to: destination)
    }

    func receiveDrop(_ urls: [URL], target: DropTargetKind, optionPressed: Bool) {
        guard !isTransferring, model != nil, case .folder(let destination) = target else { return }
        let items = urls.compactMap { url -> PendingTransfer? in
            let sameVolume = FileTransfer.Operations.live.sameVolume(url, destination)
            switch DropDecision.item(source: url, target: target, sameVolume: sameVolume, optionPressed: optionPressed) {
            case .refuse:
                return nil
            case .copy:
                return PendingTransfer(url: url, moving: false)
            case .move:
                return PendingTransfer(url: url, moving: true)
            }
        }
        guard !items.isEmpty else { return }
        startTransfer(items, to: destination)
    }

    private func startTransfer(_ items: [PendingTransfer], to destination: URL) {
        guard let transfers else { return }
        isTransferring = true
        Task {
            let run = await transfers.run(items, to: destination)
            if !run.records.isEmpty {
                installUndo()
                transferUndo.register(
                    undoManager: undoManager,
                    items: run.records,
                    actionName: items.allSatisfy(\.moving) ? "Move" : "Copy"
                )
                listSelection = Set(run.selection)
            }
            isTransferring = false
        }
    }

    private func installUndo() {
        renameUndo.perform = { [weak self] url, newName in
            await self?.performRename(of: url, to: newName, registersUndo: false) ?? false
        }
        trashUndo.putBack = { [weak self] items in
            await self?.trashes?.restore(items) ?? items
        }
        newFolderUndo.undo = { [weak self] url, identity in
            await self?.undoNewFolder(url, identity: identity)
        }
        transferUndo.undo = { [weak self] items in
            await self?.undoTransfer(items) ?? items
        }
    }

    private func performRename(of url: URL, to newName: String, registersUndo: Bool) async -> Bool {
        guard let model, let renames else { return false }
        installUndo()
        guard let newURL = await renames.rename(url, to: newName) else { return false }
        listSelection = Set(listSelection.map { RenamedPath.url($0, from: url, to: newURL) })
        if let quickLookURL {
            self.quickLookURL = RenamedPath.url(quickLookURL, from: url, to: newURL)
        }
        await model.applyRenamedItem(from: url, to: newURL)
        if registersUndo {
            renameUndo.register(undoManager: undoManager, from: url, to: newURL)
        }
        appLogger.info("Renamed \(url.path, privacy: .public) to \(newURL.path, privacy: .public)")
        return true
    }

    private func undoNewFolder(_ url: URL, identity: CreatedFolderIdentity) async {
        guard let model, let trashes, identity.stillIdentifies(url) else { return }
        if let session = renameSession, Favorites.key(for: session.url) == Favorites.key(for: url) {
            renameSession = nil
        }
        guard await trashes.trashCreatedFolder(url) else { return }
        listSelection = listSelection.filter { Favorites.key(for: $0) != Favorites.key(for: url) }
        await model.refresh()
    }

    private func undoTransfer(_ items: [TransferUndoItem]) async -> [TransferUndoItem] {
        guard let transfers else { return items }
        if let session = renameSession, items.contains(where: { Favorites.key(for: $0.write.url) == Favorites.key(for: session.url) }) {
            renameSession = nil
        }
        return await transfers.undo(items)
    }
}
