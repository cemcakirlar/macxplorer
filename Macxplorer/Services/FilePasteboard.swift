import AppKit

enum FilePasteboard {
    static func write(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects(urls as [NSURL])
    }

    static func read() -> [URL] {
        guard let objects = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: readingOptions) as? [URL] else {
            return []
        }
        return objects.filter(\.isFileURL)
    }

    static func hasFileURLs() -> Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSURL.self], options: readingOptions)
    }

    private static var readingOptions: [NSPasteboard.ReadingOptionKey: Any] {
        [.urlReadingFileURLsOnly: true]
    }
}
