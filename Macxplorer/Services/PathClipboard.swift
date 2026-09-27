import AppKit

enum PathClipboard {
    static func copy(urls: some Sequence<URL>) {
        write(CopiedPaths.text(for: urls))
    }

    static func copyNames(urls: some Sequence<URL>) {
        write(CopiedPaths.names(for: urls))
    }

    static func copyAbbreviated(
        urls: some Sequence<URL>,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        write(CopiedPaths.abbreviatedText(for: urls, home: home))
    }

    private static func write(_ text: String) {
        guard !text.isEmpty else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }
}
