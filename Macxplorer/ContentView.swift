import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings
    @State private var model = BrowserModel()
    @State private var actionError: String?

    var body: some View {
        NavigationSplitView {
            SidebarTreeView(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 480)
        } detail: {
            FileListView(model: model)
                .navigationTitle(detailTitle)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                PathBarView(url: model.selectedURL) { url in
                    Task { await model.navigate(to: url) }
                }
                .frame(minWidth: 240, idealWidth: 480, maxWidth: 720)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $settings.showHidden) {
                    Label("Hidden", systemImage: model.showHidden ? "eye" : "eye.slash")
                }
                .toggleStyle(.button)
                .keyboardShortcut(KeyEquivalent("."), modifiers: [.command, .shift])
                .help("Show or hide hidden files")

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Reload the current folder")

                Button {
                    openInFinder()
                } label: {
                    Label("Finder", systemImage: "folder")
                }
                .disabled(model.selectedURL == nil)
                .help("Open the current folder in Finder")

                Button {
                    openInTerminal()
                } label: {
                    Label("Terminal", systemImage: "terminal")
                }
                .disabled(model.selectedURL == nil)
                .help("Open the current folder in Terminal")
            }
        }
        .task {
            await model.bootstrap()
        }
        .onChange(of: settings.showHidden) { _, show in
            Task { await model.setShowHidden(show) }
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

    private var detailTitle: String {
        guard let selectedURL = model.selectedURL else { return "MacXplorer" }
        return FileManager.default.displayName(atPath: selectedURL.path)
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

    private func openInTerminal() {
        guard let url = model.selectedURL else { return }
        let terminalURL = URL(fileURLWithPath: settings.terminalAppPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [url],
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
                appLogger.info("Opened Terminal at \(url.path, privacy: .public)")
            }
        }
    }
}
