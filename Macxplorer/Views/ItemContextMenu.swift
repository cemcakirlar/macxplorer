import SwiftUI

struct ItemActions {
    var revealInFinder: ([URL]) -> Void
    var openInTerminal: ([URL]) -> Void
    var quickLook: (URL) -> Void
}

struct FavoriteMenuItem {
    var action: Favorites.MenuAction
    var perform: (Favorites.MenuAction) -> Void
}

struct ItemContextMenu: View {
    var urls: [URL]
    var opensAsFolder: (URL) -> Bool
    var actions: ItemActions
    var favorite: FavoriteMenuItem?
    /// A favorite whose folder is gone keeps only Copy Path and the favorite item.
    var targetIsMissing = false

    var body: some View {
        if targetIsMissing {
            copyPathButton
        } else {
            fullMenu
        }

        if let favorite {
            Divider()

            Button(favorite.action.title) {
                favorite.perform(favorite.action)
            }
        }
    }

    @ViewBuilder
    private var fullMenu: some View {
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

        copyPathButton

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

    private var copyPathButton: some View {
        Button("Copy Path") {
            PathClipboard.copy(urls: urls)
        }
        .disabled(urls.isEmpty)
    }
}
