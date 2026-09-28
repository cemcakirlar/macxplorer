import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings
    @State private var model = BrowserModel()
    @State private var listSelection = Set<URL>()
    @State private var quickLookURL: URL?
    @State private var actionAlert: ActionAlert?
    @State private var renameSession: RenameSession?
    @State private var extensionPrompt: RenameExtensionPrompt?
    @State private var renameRefocusID = 0
    @State private var renameAcceptsCommit = false
    @State private var renameUndo = RenameUndoRelay()
    @State private var trashUndo = TrashUndoRelay()
    @State private var newFolderUndo = NewFolderUndoRelay()
    @State private var transferUndo = TransferUndoRelay()
    @State private var pasteboardToken = 0
    @State private var isTransferring = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        columns
            .focusedSceneValue(\.copyPathAction, copyPathAction)
            .focusedSceneValue(\.newFolderAction, newFolderAction)
            .focusedSceneValue(\.fileEditAction, fileEditAction)
            .task {
                await model.bootstrap()
            }
            .onAppear(perform: installUndo)
            .onChange(of: model.selectedURL) { _, _ in
                if model.consumeRenameNavigation() {
                    return
                }
                listSelection = []
                quickLookURL = nil
            }
            .onChange(of: listSelection) { _, newValue in
                guard let quickLookURL else { return }
                if newValue != Set([quickLookURL]) {
                    self.quickLookURL = nil
                }
            }
            .onChange(of: settings.showHidden) { _, show in
                Task { await model.setShowHiddenInList(show) }
            }
            .onChange(of: settings.showHiddenInSidebar) { _, show in
                Task { await model.setShowHiddenInSidebar(show) }
            }
            .onChange(of: rootLabelSignature) { _, _ in
                model.applyRootLabels()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                pasteboardToken += 1
            }
            .alert(
                actionAlert?.title ?? "",
                isPresented: actionAlertIsPresented,
                actions: { actionAlertButtons },
                message: {
                    Text(actionAlert?.message ?? "")
                }
            )
            .alert(
                extensionPrompt?.title ?? "",
                isPresented: extensionPromptIsPresented,
                actions: {
                    let prompt = extensionPrompt
                    Button(prompt?.keepButton ?? "Keep") {
                        keepCurrentExtension(prompt)
                    }
                    Button(prompt?.useButton ?? "Use") {
                        useProposedExtension()
                    }
                }
            )
    }

    private var columns: some View {
        NavigationSplitView {
            SidebarTreeView(model: model, actions: itemActions, rename: renameEditing, receiveDrop: receiveDrop)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 480)
        } detail: {
            FileListView(
                model: model,
                rowSelection: $listSelection,
                actions: itemActions,
                rename: renameEditing,
                receiveDrop: receiveDrop
            )
            .navigationTitle(detailTitle)
        }
        .inspector(isPresented: $settings.showPreview) {
            PreviewInspector(
                entries: model.entries,
                selection: listSelection,
                focusedURL: quickLookURL,
                autoplay: settings.previewAutoplay
            )
            .inspectorColumnWidth(min: 220, ideal: 280, max: 900)
        }
        .toolbar {
            navigationToolbar
            pathToolbar
            actionToolbar
        }
    }

    @ViewBuilder
    private var actionAlertButtons: some View {
        let kind = actionAlert?.kind
        switch kind {
        case .collision(let onChoice):
            Button("Keep Both") {
                onChoice(.keepBoth)
            }
            .keyboardShortcut(.defaultAction)
            Button("Stop", role: .cancel) {
                onChoice(.stop)
            }
            Button("Replace") {
                onChoice(.replace)
            }
        default:
            Button("OK", role: .cancel) {
                guard renameSession != nil else { return }
                renameAcceptsCommit = true
                renameRefocusID += 1
            }
        }
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                Task { await model.goBack() }
            } label: {
                Label("Back", systemImage: "chevron.backward")
            }
            .disabled(!model.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
            .help("Back")

            Button {
                Task { await model.goForward() }
            } label: {
                Label("Forward", systemImage: "chevron.forward")
            }
            .disabled(!model.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            .help("Forward")

            Button {
                Task { await model.goUp() }
            } label: {
                Label("Up", systemImage: "arrow.up")
            }
            .disabled(!model.canGoUp)
            .keyboardShortcut(.upArrow, modifiers: .command)
            .help("Enclosing folder")
        }
    }

    @ToolbarContentBuilder
    private var pathToolbar: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .principal) {
                pathBar
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) {
                pathBar
            }
        }
    }

    private var pathBar: some View {
        PathBarView(url: model.selectedURL) { url in
            Task { await model.navigate(to: url) }
        }
        .frame(minWidth: 240, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private var actionToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: $settings.showHidden) {
                Label("Hidden", systemImage: model.showHiddenInList ? "eye" : "eye.slash")
            }
            .toggleStyle(.button)
            .keyboardShortcut(KeyEquivalent("."), modifiers: [.command, .shift])
            .help("Show or hide hidden files in the list")

            Button {
                Task { await model.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("Reload the current folder")

            Toggle(isOn: $settings.showPreview) {
                Label("Preview", systemImage: "sidebar.trailing")
            }
            .toggleStyle(.button)
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help("Show or hide the preview")

            Button {
                openInFinder()
            } label: {
                Label("Finder", systemImage: "folder")
            }
            .disabled(model.selectedURL == nil)
            .help("Open the current folder in Finder")

            Button {
                openCurrentFolderInTerminal()
            } label: {
                Label("Terminal", systemImage: "terminal")
            }
            .disabled(model.selectedURL == nil)
            .help("Open the current folder in Terminal")
        }
    }

    private var rootLabelSignature: String {
        "\(settings.sidebarRootHome)\n\(settings.sidebarRootRoot)\n\(settings.sidebarRootVolumes)"
    }

    private var copyPathAction: CopyPathAction {
        let urls = copyPathURLs
        return CopyPathAction(isEnabled: !urls.isEmpty) {
            PathClipboard.copy(urls: urls)
        }
    }

    private var newFolderAction: NewFolderAction {
        NewFolderAction(isEnabled: model.selectedURL != nil) {
            createNewFolder()
        }
    }

    private var fileEditAction: FileEditAction {
        FileEditAction(
            textEditing: renameSession != nil,
            canPasteFiles: canPasteFiles,
            pasteFiles: { pasteFromClipboard(moving: false) },
            moveFiles: { pasteFromClipboard(moving: true) },
            notePasteboardChange: { pasteboardToken += 1 }
        )
    }

    private var canPasteFiles: Bool {
        _ = pasteboardToken
        return !isTransferring && model.selectedURL != nil && FilePasteboard.hasFileURLs()
    }

    private var copyPathURLs: [URL] {
        if !listSelection.isEmpty {
            return Array(listSelection)
        }
        if let selectedURL = model.selectedURL {
            return [selectedURL]
        }
        return []
    }

    private var detailTitle: String {
        guard let selectedURL = model.selectedURL else { return "MacXplorer" }
        return FileManager.default.displayName(atPath: selectedURL.path)
    }

    private var itemActions: ItemActions {
        ItemActions(
            revealInFinder: revealInFinder,
            openInTerminal: openInTerminal(directories:),
            quickLook: quickLook,
            rename: beginRename,
            moveToTrash: moveToTrash,
            newFolder: createNewFolder,
            copyFiles: { urls in
                FilePasteboard.write(urls)
                pasteboardToken += 1
            },
            pasteFiles: { pasteFromClipboard(moving: false) },
            moveFiles: { pasteFromClipboard(moving: true) },
            canPasteFiles: { canPasteFiles }
        )
    }

    private func quickLook(_ url: URL) {
        quickLookURL = url
        settings.showPreview = true
    }

    private func revealInFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        appLogger.info("Revealed \(urls.count, privacy: .public) item(s) in Finder")
    }

    private func openInFinder() {
        guard let url = model.selectedURL else { return }
        if NSWorkspace.shared.open(url) {
            appLogger.info("Opened Finder at \(url.path, privacy: .public)")
        } else {
            appLogger.info("Failed to open Finder at \(url.path, privacy: .public)")
        }
    }

    private var actionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { actionAlert != nil },
            set: { isPresented in
                if !isPresented {
                    actionAlert = nil
                }
            }
        )
    }

    private var extensionPromptIsPresented: Binding<Bool> {
        Binding(
            get: { extensionPrompt != nil },
            set: { isPresented in
                if !isPresented {
                    if extensionPrompt != nil, renameSession != nil {
                        renameAcceptsCommit = true
                    }
                    extensionPrompt = nil
                }
            }
        )
    }

    private func openCurrentFolderInTerminal() {
        guard let url = model.selectedURL else { return }
        openInTerminal(directories: [url])
    }

    private func openInTerminal(directories: [URL]) {
        guard !directories.isEmpty else { return }
        let terminalURL = URL(fileURLWithPath: settings.terminalAppPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            directories,
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { _, error in
            if let error {
                let message = error.localizedDescription
                appLogger.info("Failed to open Terminal: \(message, privacy: .public)")
                Task { @MainActor in
                    actionAlert = ActionAlert(
                        title: "Can't Open Terminal",
                        message: message
                    )
                }
            } else {
                let path = directories.map(\.path).joined(separator: ", ")
                appLogger.info("Opened Terminal at \(path, privacy: .public)")
            }
        }
    }

    private var renameEditing: RenameEditing {
        RenameEditing(
            session: renameSession,
            draft: renameDraft,
            refocusID: renameRefocusID,
            commit: commitRename,
            cancel: cancelRename,
            begin: beginRename
        )
    }

    private var renameDraft: Binding<String> {
        Binding(
            get: { renameSession?.draft ?? "" },
            set: { newValue in
                let filtered = RenameName.filtering(newValue)
                if renameSession?.draft != filtered {
                    renameAcceptsCommit = true
                }
                renameSession?.draft = filtered
            }
        )
    }

    private func installUndo() {
        renameUndo.perform = { url, newName in
            await performRename(of: url, to: newName, registersUndo: false)
        }
        trashUndo.putBack = { items in
            await restoreTrashed(items)
        }
        newFolderUndo.undo = { url, identity in
            await undoNewFolder(url, identity: identity.value)
        }
        transferUndo.undo = { items in
            await undoTransfer(items)
        }
    }

    private func beginRename(_ url: URL) {
        guard renameSession == nil else { return }
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

    private func cancelRename() {
        renameAcceptsCommit = false
        extensionPrompt = nil
        renameSession = nil
    }

    private func commitRename() {
        guard renameAcceptsCommit, let session = renameSession else { return }
        renameAcceptsCommit = false
        let decision = RenameName.decision(
            currentName: session.url.lastPathComponent,
            proposedName: session.draft,
            isFolder: session.isFolder,
            siblingNames: siblingNames(for: session.url),
            caseSensitive: volumeIsCaseSensitive(session.url),
            extensionChangeConfirmed: session.extensionChangeConfirmed
        )
        switch decision {
        case .cancel:
            renameSession = nil
        case .rejected(let rejection):
            actionAlert = ActionAlert(title: rejection.title, message: rejection.message)
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

    private func keepCurrentExtension(_ prompt: RenameExtensionPrompt?) {
        guard var session = renameSession, let prompt else { return }
        session.draft = RenameName.nameByRestoringExtension(session.draft, extension: prompt.from)
        session.extensionChangeConfirmed = true
        renameSession = session
        extensionPrompt = nil
        renameAcceptsCommit = true
        commitRename()
    }

    private func useProposedExtension() {
        guard var session = renameSession else { return }
        session.extensionChangeConfirmed = true
        renameSession = session
        extensionPrompt = nil
        renameAcceptsCommit = true
        commitRename()
    }

    private func performRename(of url: URL, to newName: String, registersUndo: Bool) async -> Bool {
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
                actionAlert = ActionAlert(title: rejection.title, message: rejection.message)
            }
            return false
        } catch {
            actionAlert = ActionAlert(title: "Can't Rename", message: error.localizedDescription)
            appLogger.info("Failed to rename \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func siblingNames(for url: URL) -> [String] {
        guard model.entries.contains(where: { $0.url.path == url.path }) else { return [] }
        return model.entries.map(\.url.lastPathComponent)
    }

    private func volumeIsCaseSensitive(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames) == true
    }

    private func moveToTrash(_ urls: [URL]) {
        let targets = TrashTargets.roots(among: urls)
        guard !targets.isEmpty else { return }
        Task {
            var moved: [TrashedItem] = []
            var failures: [String] = []
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
                actionAlert = ActionAlert(
                    title: "Can't Move to Trash",
                    message: failures.joined(separator: "\n")
                )
            }
        }
    }

    private func restoreTrashed(_ items: [TrashedItem]) async -> [TrashedItem] {
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
            let names = taken.map { "The name “\($0)” is already taken. The item stayed in the Trash." }
            actionAlert = ActionAlert(title: "Name Already Taken", message: names.joined(separator: "\n"))
        } else if let message = other.first {
            actionAlert = ActionAlert(title: "Can't Move to Trash", message: message)
        }
        return remaining
    }

    private func createNewFolder() {
        guard let parent = model.selectedURL else { return }
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
                actionAlert = ActionAlert(title: "Can't Create Folder", message: error.localizedDescription)
                appLogger.info("Failed to create folder in \(parent.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func undoNewFolder(_ url: URL, identity: NSObject?) async {
        guard stillTheCreatedFolder(url, identity: identity) else { return }
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
            actionAlert = ActionAlert(title: "Can't Move to Trash", message: error.localizedDescription)
            appLogger.info("Failed to undo new folder at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
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

    private func pasteFromClipboard(moving: Bool) {
        guard renameSession == nil, !isTransferring, let destination = model.selectedURL else { return }
        let sources = FilePasteboard.read()
        guard !sources.isEmpty else { return }
        isTransferring = true
        Task {
            await transfer(sources.map { PendingTransfer(url: $0, moving: moving) }, to: destination)
            isTransferring = false
        }
    }

    private func receiveDrop(_ urls: [URL], target: DropTargetKind, optionPressed: Bool) {
        guard !isTransferring, case .folder(let destination) = target else { return }
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
            await transfer(items, to: destination)
            isTransferring = false
        }
    }

    private func transfer(_ items: [PendingTransfer], to destination: URL) async {
        let caseSensitive = (try? destination.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames) == true
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
            if TransferNames.destinationIsInside(source, destinationDirectory: destination) {
                failures.append("“\(name)” can’t be copied into itself.")
                continue
            }
            let proposed = transferDestination(for: source, name: name, in: destination)
            if TransferNames.sameItem(source, proposed, caseSensitive: caseSensitive) {
                if moving {
                    continue
                }
                let unique = TransferNames.keepBothName(
                    for: name,
                    existing: siblingNames(in: destination),
                    caseSensitive: caseSensitive
                )
                await writeTransfer(
                    from: source,
                    to: transferDestination(for: source, name: unique, in: destination),
                    moving: false,
                    replacing: false,
                    records: &records,
                    failures: &failures
                )
                continue
            }
            switch TransferNames.decision(
                name: name,
                existing: siblingNames(in: destination),
                caseSensitive: caseSensitive,
                choice: choice
            ) {
            case .stop:
                pending = []
            case .ask:
                let picked = await askTransferChoice(name: name, moving: moving, appliesToRest: !pending.isEmpty)
                choice = picked
                if picked == .stop {
                    pending = []
                } else {
                    pending.insert(item, at: 0)
                }
            case .write(let destinationName):
                await writeTransfer(
                    from: source,
                    to: transferDestination(for: source, name: destinationName, in: destination),
                    moving: moving,
                    replacing: false,
                    records: &records,
                    failures: &failures
                )
            case .replace(let destinationName):
                await writeTransfer(
                    from: source,
                    to: transferDestination(for: source, name: destinationName, in: destination),
                    moving: moving,
                    replacing: true,
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
            let listed = await model.refreshedEntries(matching: records.map(\.write.url))
            listSelection = Set(listed.isEmpty ? records.map(\.write.url) : listed)
            appLogger.info("Transferred \(records.count, privacy: .public) item(s) into \(destination.path, privacy: .public)")
        }
        if !failures.isEmpty {
            actionAlert = ActionAlert(
                title: items.allSatisfy(\.moving) ? "Can't Move" : "Can't Copy",
                message: failures.joined(separator: "\n")
            )
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
                failures.append("The name “\(name)” is already taken.")
            case .trashFailed(let name):
                failures.append("“\(name)” couldn’t be moved to the Trash, so it was left in place.")
            case .insideItself(let name):
                failures.append("“\(name)” can’t be copied into itself.")
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
        let gate = TransferChoiceGate()
        return await withCheckedContinuation { continuation in
            actionAlert = ActionAlert(
                title: "“\(name)” already exists in this location.",
                message: message,
                kind: .collision(onChoice: { choice in
                    gate.resume(continuation, with: choice)
                })
            )
        }
    }

    private func siblingNames(in folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
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

    private func undoTransfer(_ items: [TransferUndoItem]) async -> [TransferUndoItem] {
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
            actionAlert = ActionAlert(title: "Can't Undo", message: messages.joined(separator: "\n"))
        }
        return remaining
    }

    private func undoTransferItem(_ item: TransferUndoItem) async -> String? {
        let write = item.write
        let occupiesDestination = stillTheCreatedFolder(write.url, identity: item.identity.value)
        if let movedFrom = write.movedFrom {
            if occupiesDestination {
                if FileManager.default.fileExists(atPath: movedFrom.path) {
                    return "The name “\(movedFrom.lastPathComponent)” is already taken. The item stayed where it is."
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
                return "The name “\(source.original.lastPathComponent)” is already taken. The item stayed where it is."
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
            return "The name “\(item.original.lastPathComponent)” is already taken. The earlier item stayed in the Trash."
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
}

private struct PendingTransfer: Sendable {
    var url: URL
    var moving: Bool
}

struct ActionAlert: Identifiable {
    enum Kind {
        case acknowledge
        case collision(onChoice: (TransferChoice) -> Void)
    }

    let id = UUID()
    var title: String
    var message: String
    var kind: Kind = .acknowledge
}

private final class TransferChoiceGate: @unchecked Sendable {
    private var resumed = false

    func resume(_ continuation: CheckedContinuation<TransferChoice, Never>, with choice: TransferChoice) {
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: choice)
    }
}
