import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsTab(settings: settings)
            }
            Tab("Preview", systemImage: "play.rectangle") {
                PreviewSettingsTab(settings: settings)
            }
            Tab("Sidebar", systemImage: "sidebar.left") {
                SidebarSettingsTab(settings: settings)
            }
        }
        .frame(width: 460, height: 280)
    }
}

private struct GeneralSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show hidden files in list", isOn: $settings.showHidden)
                Toggle("Reopen last folder", isOn: $settings.reopenLastFolder)
                LabeledContent("Terminal app") {
                    Picker("Terminal app", selection: $settings.terminalAppPath) {
                        ForEach(terminalChoices) { choice in
                            Text(choice.name).tag(choice.path)
                        }
                    }
                    .labelsHidden()
                    Button("Other…") {
                        chooseTerminalApp()
                    }
                }
            }
            Button("Restore Defaults") {
                settings.restoreDefaults()
            }
        }
        .formStyle(.grouped)
    }

    private var terminalChoices: [TerminalChoice] {
        var choices = TerminalApps.installed()
        let current = settings.terminalAppPath
        if !choices.contains(where: { $0.path == current }) {
            let name = FileManager.default.displayName(atPath: current)
            choices.append(TerminalChoice(name: name, path: current))
        }
        return choices
    }

    private func chooseTerminalApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.terminalAppPath = url.standardizedFileURL.path
    }
}

private struct PreviewSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Play media automatically", isOn: $settings.previewAutoplay)
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SidebarSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Show hidden folders in sidebar", isOn: $settings.showHiddenInSidebar)
            TextField("Home", text: $settings.sidebarRootHome)
            TextField("Root", text: $settings.sidebarRootRoot)
            TextField("Volumes", text: $settings.sidebarRootVolumes)
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
