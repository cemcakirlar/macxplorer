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
        guard renameAcceptsCommit, let session = renameSession, let model else { return }
        renameAcceptsCommit = false
        let decision = RenameName.decision(
            currentName: session.url.lastPathComponent,
            proposedName: session.draft,
            isFolder: session.isFolder,
            siblingNames: siblingNames(for: session.url, model: model),
            caseSensitive: volumeIsCaseSensitive(session.url),
            extensionChangeConfirmed: session.extensionChangeConfirmed
        )
        switch decision {
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
        let roots = TrashTargets.roots(among: urls)
        let targets = roots.filter { !ProtectedFolders.contains($0) }
        let refused = roots.filter { ProtectedFolders.contains($0) }.map {
            "“\(ProtectedFolders.displayName($0))” is required by macOS and stayed in place."
        }
        guard !roots.isEmpty, let model else { return }
        Task {
            if !targets.isEmpty {
                let confirmed = await alerts.confirm(ActionAlert(
                    title: FileAlertCopy.trashConfirmationTitle(targets.map(ProtectedFolders.displayName)),
                    message: "You can put it back from the Trash, or undo with Command-Z.",
                    kind: .confirmTrash
                ))
                guard confirmed else { return }
            }
            var moved: [TrashedItem] = []
            var failures = refused
            for url in targets {
                do {
                    let trashedURL = try await Task.detached {
                        try FileTrash.trash(at: url)
                    }.value
                    moved.append(TrashedItem(original: url, trashed: trashedURL))
                } catch {
                    let message = "“\(url.lastPathComponent)” stayed in place. \(error.localizedDescription)"
                    failures.append(message)
                    appLogger.info("Failed to trash \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            if !moved.isEmpty {
                let roots = moved.map(\.original)
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
                trashUndo.register(undoManager: undoManager, items: moved)
                appLogger.info("Moved \(moved.count, privacy: .public) item(s) to the Trash")
            }
            if !failures.isEmpty {
                alerts.show(ActionAlert(
                    title: "Can't Move to Trash",
                    message: failures.joined(separator: "\n")
                ))
            }
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
                    identity: CreatedFolderIdentity(folderIdentity(created))
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
        isTransferring = true
        Task {
            await transfer(sources.map { PendingTransfer(url: $0, moving: moving) }, to: destination, model: model)
            isTransferring = false
        }
    }

    func receiveDrop(_ urls: [URL], target: DropTargetKind, optionPressed: Bool) {
        guard !isTransferring, let model, case .folder(let destination) = target else { return }
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
        isTransferring = true
        Task {
            await transfer(items, to: destination, model: model)
            isTransferring = false
        }
    }

    private func installUndo() {
        renameUndo.perform = { [weak self] url, newName in
            await self?.performRename(of: url, to: newName, registersUndo: false) ?? false
        }
        trashUndo.putBack = { [weak self] items in
            await self?.restoreTrashed(items) ?? items
        }
        newFolderUndo.undo = { [weak self] url, identity in
            await self?.undoNewFolder(url, identity: identity.value)
        }
        transferUndo.undo = { [weak self] items in
            await self?.undoTransfer(items) ?? items
        }
    }

    private func performRename(of url: URL, to newName: String, registersUndo: Bool) async -> Bool {
        guard let model else { return false }
        installUndo()
        do {
            let newURL = try await Task.detached {
                try FileRename.apply(at: url, to: newName)
            }.value
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
        } catch let error as FileRenameError {
            if case .nameTaken(let name) = error {
                let rejection = RenameRejection.nameTaken(name)
                alerts.show(ActionAlert(title: rejection.title, message: rejection.message))
            }
            return false
        } catch {
            alerts.show(ActionAlert(title: "Can't Rename", message: error.localizedDescription))
            appLogger.info("Failed to rename \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func restoreTrashed(_ items: [TrashedItem]) async -> [TrashedItem] {
        guard let model else { return items }
        var remaining: [TrashedItem] = []
        var taken: [String] = []
        var other: [String] = []
        for item in items {
            do {
                try await Task.detached {
                    try FileTrash.putBack(trashed: item.trashed, to: item.original)
                }.value
            } catch let error as FileTrashError {
                remaining.append(item)
                if case .nameTaken(let name) = error {
                    taken.append(name)
                }
            } catch {
                remaining.append(item)
                other.append(error.localizedDescription)
                appLogger.info("Failed to put back \(item.original.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        if remaining.count < items.count {
            await model.refresh()
        }
        if !taken.isEmpty {
            let names = taken.map { FileAlertCopy.nameTaken($0, detail: "The item stayed in the Trash.") }
            alerts.show(ActionAlert(title: "Name Already Taken", message: names.joined(separator: "\n")))
        } else if let message = other.first {
            alerts.show(ActionAlert(title: "Can't Move to Trash", message: message))
        }
        return remaining
    }

    private func undoNewFolder(_ url: URL, identity: NSObject?) async {
        guard let model, stillTheCreatedFolder(url, identity: identity) else { return }
        if let session = renameSession, Favorites.key(for: session.url) == Favorites.key(for: url) {
            renameSession = nil
        }
        do {
            _ = try await Task.detached {
                try FileTrash.trash(at: url)
            }.value
            listSelection = listSelection.filter { Favorites.key(for: $0) != Favorites.key(for: url) }
            await model.refresh()
        } catch {
            alerts.show(ActionAlert(title: "Can't Move to Trash", message: error.localizedDescription))
            appLogger.info("Failed to undo new folder at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func transfer(_ items: [PendingTransfer], to destination: URL, model: BrowserModel) async {
        let caseSensitive = volumeIsCaseSensitive(destination)
        var pending = items
        var choice: TransferChoice?
        var records: [TransferUndoItem] = []
        var failures: [String] = []

        while let item = pending.first {
            pending.removeFirst()
            let source = item.url
            let moving = item.moving
            let name = source.lastPathComponent
            if !transferItemExists(source) {
                failures.append("“\(name)” can’t be found.")
                continue
            }
            if moving, ProtectedFolders.contains(source) {
                failures.append("“\(ProtectedFolders.displayName(source))” is required by macOS and can’t be moved.")
                continue
            }
            if TransferNames.destinationIsInside(source, destinationDirectory: destination) {
                failures.append("“\(name)” can’t be copied into itself.")
                continue
            }
            let proposed = transferDestination(for: source, name: name, in: destination)
            switch TransferNames.step(
                source: source,
                proposed: proposed,
                moving: moving,
                existing: siblingNames(in: destination),
                caseSensitive: caseSensitive,
                choice: choice
            ) {
            case .skip:
                continue
            case .stop:
                pending = []
            case .ask(let askedName):
                let picked = await askTransferChoice(name: askedName, moving: moving, appliesToRest: !pending.isEmpty)
                choice = picked
                if picked == .stop {
                    pending = []
                } else {
                    pending.insert(item, at: 0)
                }
            case .write(let destinationName, let replacing):
                await writeTransfer(
                    from: source,
                    to: transferDestination(for: source, name: destinationName, in: destination),
                    moving: moving,
                    replacing: replacing,
                    records: &records,
                    failures: &failures
                )
            }
        }

        if !records.isEmpty {
            installUndo()
            transferUndo.register(
                undoManager: undoManager,
                items: records,
                actionName: items.allSatisfy(\.moving) ? "Move" : "Copy"
            )
            let written = records.map(\.write.url)
            let listed: [URL]
            if destination.directoryKey.path != model.selectedURL?.directoryKey.path {
                model.holdListSelection(across: destination)
                await model.navigate(to: destination)
                if records.contains(where: movedFolder) {
                    await model.reloadExpandedTree()
                }
                listed = await model.listedMatches(for: written)
            } else {
                listed = await model.refreshedEntries(matching: written)
            }
            listSelection = Set(listed.isEmpty ? written : listed)
            appLogger.info("Transferred \(records.count, privacy: .public) item(s) into \(destination.path, privacy: .public)")
        }
        if !failures.isEmpty {
            alerts.show(ActionAlert(
                title: items.allSatisfy(\.moving) ? "Can't Move" : "Can't Copy",
                message: failures.joined(separator: "\n")
            ))
        }
    }

    private func writeTransfer(
        from source: URL,
        to destination: URL,
        moving: Bool,
        replacing: Bool,
        records: inout [TransferUndoItem],
        failures: inout [String]
    ) async {
        do {
            let write = try await Task.detached {
                try FileTransfer.perform(from: source, to: destination, moving: moving, replacing: replacing)
            }.value
            records.append(TransferUndoItem(write: write, identity: CreatedFolderIdentity(folderIdentity(write.url))))
        } catch let error as FileTransferError {
            switch error {
            case .copiedButSourceRemained(let write):
                records.append(TransferUndoItem(write: write, identity: CreatedFolderIdentity(folderIdentity(write.url))))
                failures.append("“\(source.lastPathComponent)” was copied, but the original couldn’t be moved to the Trash.")
            case .nameTaken(let name):
                failures.append(FileAlertCopy.nameTaken(name))
            case .trashFailed(let name):
                failures.append("“\(name)” couldn’t be moved to the Trash, so it was left in place.")
            case .occupantLeftInTrash(let name):
                failures.append("“\(name)” stayed in the Trash because the new item couldn’t be written.")
            case .insideItself(let name):
                failures.append("“\(name)” can’t be copied into itself.")
            case .sameItem(let name):
                failures.append("“\(name)” can’t be replaced with itself.")
            }
        } catch {
            failures.append(error.localizedDescription)
            appLogger.info("Failed to transfer \(source.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func askTransferChoice(name: String, moving: Bool, appliesToRest: Bool) async -> TransferChoice {
        let verb = moving ? "moving" : "copying"
        var message = "Do you want to replace it with the one you're \(verb)?"
        if appliesToRest {
            message += " This choice applies to the remaining items."
        }
        return await alerts.ask(ActionAlert(
            title: "“\(name)” already exists in this location.",
            message: message,
            kind: .collision
        ))
    }

    private func undoTransfer(_ items: [TransferUndoItem]) async -> [TransferUndoItem] {
        guard let model else { return items }
        if let session = renameSession, items.contains(where: { Favorites.key(for: $0.write.url) == Favorites.key(for: session.url) }) {
            renameSession = nil
        }
        var remaining: [TransferUndoItem] = []
        var messages: [String] = []
        for item in items.reversed() {
            if let message = await undoTransferItem(item) {
                messages.append(message)
                remaining.append(item)
            }
        }
        await model.refresh()
        if !messages.isEmpty {
            alerts.show(ActionAlert(title: "Can't Undo", message: messages.joined(separator: "\n")))
        }
        return remaining
    }

    private func undoTransferItem(_ item: TransferUndoItem) async -> String? {
        let write = item.write
        let occupiesDestination = stillTheCreatedFolder(write.url, identity: item.identity.value)
        if let movedFrom = write.movedFrom {
            if occupiesDestination {
                if FileManager.default.fileExists(atPath: movedFrom.path) {
                    return FileAlertCopy.nameTaken(movedFrom.lastPathComponent, detail: "The item stayed where it is.")
                }
                do {
                    _ = try await Task.detached {
                        try FileTransfer.perform(from: write.url, to: movedFrom, moving: true, replacing: false)
                    }.value
                } catch {
                    return error.localizedDescription
                }
            }
            return await restoreDisplaced(write.displaced)
        }
        if let source = write.crossVolumeSource {
            if FileManager.default.fileExists(atPath: source.original.path) {
                return FileAlertCopy.nameTaken(source.original.lastPathComponent, detail: "The item stayed where it is.")
            }
            do {
                try await Task.detached {
                    try FileTrash.putBack(trashed: source.trashed, to: source.original)
                }.value
            } catch {
                return error.localizedDescription
            }
            if occupiesDestination {
                do {
                    _ = try await Task.detached {
                        try FileTrash.trash(at: write.url)
                    }.value
                } catch {
                    return error.localizedDescription
                }
            }
            return await restoreDisplaced(write.displaced)
        }
        if occupiesDestination {
            do {
                _ = try await Task.detached {
                    try FileTrash.trash(at: write.url)
                }.value
            } catch {
                return error.localizedDescription
            }
        }
        return await restoreDisplaced(write.displaced)
    }

    private func restoreDisplaced(_ item: TrashedItem?) async -> String? {
        guard let item else { return nil }
        if FileManager.default.fileExists(atPath: item.original.path) {
            return FileAlertCopy.nameTaken(item.original.lastPathComponent, detail: "The earlier item stayed in the Trash.")
        }
        do {
            try await Task.detached {
                try FileTrash.putBack(trashed: item.trashed, to: item.original)
            }.value
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// A sidebar folder is usually not in the open listing, so its siblings come from disk.
    private func siblingNames(for url: URL, model: BrowserModel) -> [String] {
        if model.entries.contains(where: { $0.url.path == url.path }) {
            return model.entries.map(\.url.lastPathComponent)
        }
        return siblingNames(in: url.deletingLastPathComponent())
    }

    private func siblingNames(in folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

    private func volumeIsCaseSensitive(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames) == true
    }

    private func stillTheCreatedFolder(_ url: URL, identity: NSObject?) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let identity else { return true }
        guard let current = folderIdentity(url) else { return false }
        return current.isEqual(identity)
    }

    private func folderIdentity(_ url: URL) -> NSObject? {
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey])
        return values?.fileResourceIdentifier as? NSObject
    }

    private func movedFolder(_ record: TransferUndoItem) -> Bool {
        let write = record.write
        let moved = write.movedFrom != nil || write.crossVolumeSource != nil
        guard moved else { return false }
        let values = try? write.url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        return values?.isSymbolicLink != true && values?.isDirectory == true
    }

    private func transferItemExists(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private func transferDestination(for source: URL, name: String, in parent: URL) -> URL {
        let values = try? source.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        let isDirectory = values?.isSymbolicLink != true && values?.isDirectory == true
        return parent.appendingPathComponent(name, isDirectory: isDirectory)
    }
}

private struct PendingTransfer: Sendable {
    var url: URL
    var moving: Bool
}
