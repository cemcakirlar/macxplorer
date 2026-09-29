import Foundation

enum FolderNames {
    static func names(in folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

    static func isCaseSensitive(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames) == true
    }
}

@MainActor
struct RenameCoordinator {
    let model: BrowserModel
    let alerts: AlertPresenter

    func decision(for session: RenameSession) -> RenameDecision {
        RenameName.decision(
            currentName: session.url.lastPathComponent,
            proposedName: session.draft,
            isFolder: session.isFolder,
            siblingNames: siblingNames(for: session.url),
            caseSensitive: FolderNames.isCaseSensitive(session.url),
            extensionChangeConfirmed: session.extensionChangeConfirmed
        )
    }

    /// `nil` when the rename failed. The reason has already been shown.
    func rename(_ url: URL, to newName: String) async -> URL? {
        do {
            return try await Task.detached {
                try FileRename.apply(at: url, to: newName)
            }.value
        } catch let error as FileRenameError {
            if case .nameTaken(let name) = error {
                let rejection = RenameRejection.nameTaken(name)
                alerts.show(ActionAlert(title: rejection.title, message: rejection.message))
            }
            return nil
        } catch {
            alerts.show(ActionAlert(title: "Can't Rename", message: error.localizedDescription))
            appLogger.info("Failed to rename \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// A sidebar folder is usually not in the open listing, so its siblings come from disk.
    private func siblingNames(for url: URL) -> [String] {
        if model.entries.contains(where: { $0.url.path == url.path }) {
            return model.entries.map(\.url.lastPathComponent)
        }
        return FolderNames.names(in: url.deletingLastPathComponent())
    }
}
