import SwiftUI

struct ItemActions {
    var revealInFinder: ([URL]) -> Void
    var openInTerminal: ([URL]) -> Void
    var quickLook: (URL) -> Void
}

struct ItemContextMenu: View {
    var urls: [URL]
    var opensAsFolder: (URL) -> Bool
    var actions: ItemActions

    var body: some View {
        Button("Reveal in Finder") {
            actions.revealInFinder(urls)
        }
        .disabled(urls.isEmpty)

        Button("Open in Terminal") {
            actions.openInTerminal(TerminalDirectory.urls(for: urls, opensAsFolder: opensAsFolder))
        }
        .disabled(urls.isEmpty)

        Divider()

        Button("Copy Name") {
            PathClipboard.copyNames(urls: urls)
        }
        .disabled(urls.isEmpty)

        Button("Copy Path") {
            PathClipboard.copy(urls: urls)
        }
        .disabled(urls.isEmpty)

        Button("Copy Path with ~") {
            PathClipboard.copyAbbreviated(urls: urls)
        }
        .disabled(urls.isEmpty)

        Divider()

        Button("Quick Look") {
            if let url = urls.first {
                actions.quickLook(url)
            }
        }
        .disabled(urls.count != 1)
    }
}
