import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show hidden files", isOn: $settings.showHidden)
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
        .frame(width: 460)
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
