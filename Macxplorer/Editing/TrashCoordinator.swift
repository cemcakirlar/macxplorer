import Foundation

struct TrashRun {
    var moved: [TrashedItem]
    var failures: [String]
}

@MainActor
struct TrashCoordinator {
    let model: BrowserModel
    let alerts: AlertPresenter

    /// Asks first, then trashes. Protected folders stay in place. `nil` when the user cancels.
    func trash(_ urls: [URL]) async -> TrashRun? {
        let roots = TrashTargets.roots(among: urls)
        let targets = roots.filter { !ProtectedFolders.contains($0) }
        var failures = roots.filter { ProtectedFolders.contains($0) }.map {
            "“\(ProtectedFolders.displayName($0))” is required by macOS and stayed in place."
        }
        if !targets.isEmpty {
            let confirmed = await alerts.confirm(ActionAlert(
                title: FileAlertCopy.trashConfirmationTitle(targets.map(ProtectedFolders.displayName)),
                message: "You can put it back from the Trash, or undo with Command-Z.",
                kind: .confirmTrash
            ))
            guard confirmed else { return nil }
        }
        var moved: [TrashedItem] = []
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
        return TrashRun(moved: moved, failures: failures)
    }

    func report(_ failures: [String]) {
        guard !failures.isEmpty else { return }
        alerts.show(ActionAlert(
            title: "Can't Move to Trash",
            message: failures.joined(separator: "\n")
        ))
    }

    /// Puts items back. Returns the ones that stayed in the Trash.
    func restore(_ items: [TrashedItem]) async -> [TrashedItem] {
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

    /// Undoes New Folder. `false` when the folder stayed, and the reason has been shown.
    func trashCreatedFolder(_ url: URL) async -> Bool {
        do {
            _ = try await Task.detached {
                try FileTrash.trash(at: url)
            }.value
            return true
        } catch {
            alerts.show(ActionAlert(title: "Can't Move to Trash", message: error.localizedDescription))
            appLogger.info("Failed to undo new folder at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
