import Foundation

struct PendingTransfer: Sendable {
    var url: URL
    var moving: Bool
}

struct TransferRun {
    var records: [TransferUndoItem]
    /// The written items as listed after the transfer, for the list selection.
    var selection: [URL]
}

@MainActor
struct TransferCoordinator {
    let model: BrowserModel
    let alerts: AlertPresenter

    func run(_ items: [PendingTransfer], to destination: URL) async -> TransferRun {
        let caseSensitive = FolderNames.isCaseSensitive(destination)
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
                existing: FolderNames.names(in: destination),
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

        var selection: [URL] = []
        if !records.isEmpty {
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
            selection = listed.isEmpty ? written : listed
            appLogger.info("Transferred \(records.count, privacy: .public) item(s) into \(destination.path, privacy: .public)")
        }
        if !failures.isEmpty {
            alerts.show(ActionAlert(
                title: items.allSatisfy(\.moving) ? "Can't Move" : "Can't Copy",
                message: failures.joined(separator: "\n")
            ))
        }
        return TransferRun(records: records, selection: selection)
    }

    /// Undoes a transfer, newest item first. Returns the items that could not be undone.
    func undo(_ items: [TransferUndoItem]) async -> [TransferUndoItem] {
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
            records.append(TransferUndoItem(write: write, identity: .of(write.url)))
        } catch let error as FileTransferError {
            switch error {
            case .copiedButSourceRemained(let write):
                records.append(TransferUndoItem(write: write, identity: .of(write.url)))
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

    private func undoTransferItem(_ item: TransferUndoItem) async -> String? {
        let write = item.write
        let occupiesDestination = item.identity.stillIdentifies(write.url)
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
