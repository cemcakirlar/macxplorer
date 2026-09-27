import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings
    @State private var model = BrowserModel()
    @State private var listSelection = Set<URL>()
    @State private var quickLookURL: URL?
    @State private var actionError: String?

    var body: some View {
        NavigationSplitView {
            SidebarTreeView(model: model, actions: itemActions)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 480)
        } detail: {
            FileListView(model: model, rowSelection: $listSelection, actions: itemActions)
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
        .focusedSceneValue(\.copyPathAction, copyPathAction)
        .task {
            await model.bootstrap()
        }
        .onChange(of: model.selectedURL) { _, _ in
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
        .alert(
            "Can't Open Terminal",
            isPresented: actionErrorIsPresented,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(actionError ?? "")
            }
        )
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
            quickLook: quickLook
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

    private var actionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { isPresented in
                if !isPresented {
                    actionError = nil
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
                    actionError = message
                }
            } else {
                let path = directories.map(\.path).joined(separator: ", ")
                appLogger.info("Opened Terminal at \(path, privacy: .public)")
            }
        }
    }
}
