import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class IconStore {
    static let shared = IconStore()

    private let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 5000
        return cache
    }()
    @ObservationIgnored private var missing: [String: URL] = [:]
    @ObservationIgnored private var refill: Task<Void, Never>?
    private(set) var revision = 0

    private init() {}

    /// A row whose icon was evicted asks for it again, so an evicted icon never stays a placeholder.
    func image(for url: URL, isDirectory: Bool) -> NSImage {
        _ = revision
        if let cached = cache.object(forKey: url.path as NSString) {
            return cached
        }
        scheduleRefill(url)
        return isDirectory ? Self.folderPlaceholder : Self.documentPlaceholder
    }

    func prefetch(_ urls: [URL]) async {
        var sinceYield = 0
        for url in urls {
            if Task.isCancelled { return }
            let key = url.path as NSString
            if cache.object(forKey: key) == nil {
                cache.setObject(makeIcon(for: url), forKey: key)
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

    private func scheduleRefill(_ url: URL) {
        missing[url.path] = url
        guard refill == nil else { return }
        refill = Task {
            await Task.yield()
            let urls = Array(missing.values)
            missing = [:]
            refill = nil
            await prefetch(urls)
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
