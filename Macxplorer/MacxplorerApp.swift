import SwiftUI

@main
struct MacxplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1100, height: 700)
        .windowToolbarStyle(.unified)
    }
}
