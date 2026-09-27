import AppKit

@MainActor
final class IconStore {
    static let shared = IconStore()

    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(for url: URL) -> NSImage {
        let key = url.path
        if let cached = cache[key] {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        let sized = (image.copy() as? NSImage) ?? image
        sized.size = NSSize(width: 16, height: 16)
        cache[key] = sized
        return sized
    }
}
