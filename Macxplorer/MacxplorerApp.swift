import os
import SwiftUI

let appLogger = Logger(subsystem: "com.cakirlarc.macxplorer", category: "app")

@main
struct MacxplorerApp: App {
    init() {
        appLogger.info("MacXplorer started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: .shared)
        }
        .defaultSize(width: 1100, height: 700)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .pasteboard) {
                CopyPathCommand()
            }
        }

        Settings {
            SettingsView(settings: .shared)
        }
    }
}

private struct CopyPathCommand: View {
    @FocusedValue(\.copyPathAction) private var copyPathAction

    var body: some View {
        Button("Copy Path") {
            copyPathAction?.perform()
        }
        .keyboardShortcut("c", modifiers: [.command, .option])
        .disabled(copyPathAction?.isEnabled != true)
    }
}
