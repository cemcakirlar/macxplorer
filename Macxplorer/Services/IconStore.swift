import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class IconStore {
    static let shared = IconStore()

    @ObservationIgnored
    private var cache: [String: NSImage] = [:]
    private(set) var revision = 0

    private init() {}

    func image(for url: URL, isDirectory: Bool) -> NSImage {
        _ = revision
        if let cached = cache[url.path] {
            return cached
        }
        return isDirectory ? Self.folderPlaceholder : Self.documentPlaceholder
    }

    func prefetch(_ urls: [URL]) async {
        var sinceYield = 0
        for url in urls {
            if Task.isCancelled { return }
            let key = url.path
            if cache[key] == nil {
                cache[key] = makeIcon(for: url)
            }
            sinceYield += 1
            if sinceYield == 24 {
                revision += 1
                sinceYield = 0
                await Task.yield()
            }
        }
        if sinceYield > 0 {
            revision += 1
        }
    }

    private func makeIcon(for url: URL) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        let sized = (image.copy() as? NSImage) ?? image
        sized.size = NSSize(width: 16, height: 16)
        return sized
    }

    private static let folderPlaceholder: NSImage = placeholder(named: NSImage.folderName)
    private static let documentPlaceholder: NSImage = placeholder(system: .data)

    private static func placeholder(named name: NSImage.Name) -> NSImage {
        let image = (NSImage(named: name)?.copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    private static func placeholder(system type: UTType) -> NSImage {
        let image = (NSWorkspace.shared.icon(for: type).copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
