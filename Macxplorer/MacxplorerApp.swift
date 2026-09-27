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

        Settings {
            SettingsView(settings: .shared)
        }
    }
}
