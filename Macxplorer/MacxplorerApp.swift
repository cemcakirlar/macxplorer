import os
import SwiftUI

let appLogger = Logger(subsystem: "com.cakirlarc.macxplorer", category: "app")

@main
struct MacxplorerApp: App {
    init() {
        appLogger.info("Macxplorer started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1100, height: 700)
        .windowToolbarStyle(.unified)
    }
}
