import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings
    @State private var model = BrowserModel()
    @State private var editing = FileEditing()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        columns
            .focusedSceneValue(\.copyPathAction, copyPathAction)
            .focusedSceneValue(\.newFolderAction, newFolderAction)
            .focusedSceneValue(\.fileEditAction, fileEditAction)
            .task {
                await model.bootstrap()
            }
            .onAppear {
                editing.bind(model: model, undoManager: undoManager)
            }
            .onChange(of: model.selectedURL) { _, _ in
                if model.consumeRenameNavigation() {
                    return
                }
                editing.listSelection = []
                editing.quickLookURL = nil
            }
            .onChange(of: editing.listSelection) { _, newValue in
                guard let quickLookURL = editing.quickLookURL else { return }
                if newValue != Set([quickLookURL]) {
                    editing.quickLookURL = nil
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
                editing.pasteboardToken += 1
                guard editing.renameSession == nil, !editing.isTransferring else { return }
                Task {
                    guard await model.refreshVisible() else { return }
                    let listed = Set(model.entries.map { Favorites.key(for: $0.url) })
                    editing.listSelection = editing.listSelection.filter { listed.contains(Favorites.key(for: $0)) }
                }
            }
            .alert(
                editing.alerts.current?.title ?? "",
                isPresented: actionAlertIsPresented,
                presenting: editing.alerts.current,
                actions: { alert in actionAlertButtons(alert) },
                message: { alert in
                    Text(alert.message)
                }
            )
            .alert(
                editing.extensionPrompt?.title ?? "",
                isPresented: extensionPromptIsPresented,
                actions: {
                    let prompt = editing.extensionPrompt
                    Button(prompt?.keepButton ?? "Keep") {
                        editing.keepCurrentExtension(prompt)
                    }
                    Button(prompt?.useButton ?? "Use") {
                        editing.useProposedExtension()
                    }
                }
            )
    }

    private var columns: some View {
        NavigationSplitView {
            SidebarTreeView(model: model, actions: itemActions, rename: renameEditing, receiveDrop: editing.receiveDrop)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 480)
        } detail: {
            FileListView(
                model: model,
                rowSelection: $editing.listSelection,
                actions: itemActions,
                rename: renameEditing,
                receiveDrop: editing.receiveDrop
            )
            .navigationTitle(detailTitle)
        }
        .inspector(isPresented: $settings.showPreview) {
            PreviewInspector(
                entries: model.entries,
                selection: editing.listSelection,
                focusedURL: editing.quickLookURL,
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
    private func actionAlertButtons(_ alert: ActionAlert) -> some View {
        switch alert.kind {
        case .collision:
            Button("Keep Both") {
                editing.alerts.finish(alert.id, choice: .keepBoth)
            }
            .keyboardShortcut(.defaultAction)
            Button("Stop", role: .cancel) {
                editing.alerts.finish(alert.id, choice: .stop)
            }
            Button("Replace") {
                editing.alerts.finish(alert.id, choice: .replace)
            }
        case .acknowledge:
            Button("OK", role: .cancel) {
                editing.alerts.finish(alert.id)
                guard editing.renameSession != nil else { return }
                editing.renameAcceptsCommit = true
                editing.renameRefocusID += 1
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
            editing.createNewFolder()
        }
    }

    private var fileEditAction: FileEditAction {
        FileEditAction(
            textEditing: editing.renameSession != nil,
            canPasteFiles: canPasteFiles,
            pasteFiles: { editing.pasteFromClipboard(moving: false) },
            moveFiles: { editing.pasteFromClipboard(moving: true) },
            notePasteboardChange: { editing.pasteboardToken += 1 }
        )
    }

    private var canPasteFiles: Bool {
        _ = editing.pasteboardToken
        return !editing.isTransferring && model.selectedURL != nil && FilePasteboard.hasFileURLs()
    }

    private var copyPathURLs: [URL] {
        if !editing.listSelection.isEmpty {
            return Array(editing.listSelection)
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
            rename: editing.beginRename,
            moveToTrash: editing.moveToTrash
        )
    }

    private func quickLook(_ url: URL) {
        editing.quickLookURL = url
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
            get: { editing.alerts.current != nil },
            set: { isPresented in
                guard !isPresented, let id = editing.alerts.current?.id else { return }
                // Deferred so a button's own choice lands first; this then finds nothing to finish.
                Task { @MainActor in
                    editing.alerts.finish(id)
                }
            }
        )
    }

    private var extensionPromptIsPresented: Binding<Bool> {
        Binding(
            get: { editing.extensionPrompt != nil },
            set: { isPresented in
                if !isPresented {
                    if editing.extensionPrompt != nil, editing.renameSession != nil {
                        editing.renameAcceptsCommit = true
                    }
                    editing.extensionPrompt = nil
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
                    editing.alerts.show(ActionAlert(
                        title: "Can't Open Terminal",
                        message: message
                    ))
                }
            } else {
                let path = directories.map(\.path).joined(separator: ", ")
                appLogger.info("Opened Terminal at \(path, privacy: .public)")
            }
        }
    }

    private var renameEditing: RenameEditing {
        RenameEditing(
            session: editing.renameSession,
            draft: editing.draft,
            refocusID: editing.renameRefocusID,
            commit: editing.commitRename,
            cancel: editing.cancelRename,
            begin: editing.beginRename
        )
    }
}
