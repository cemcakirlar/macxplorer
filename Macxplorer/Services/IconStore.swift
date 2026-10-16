import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class IconStore {
    static let shared = IconStore()
    static let listPointSize: CGFloat = 16
    static let gridPointSize: CGFloat = 64

    private let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 5000
        return cache
    }()
    @ObservationIgnored private var missing: [String: (url: URL, pointSize: CGFloat)] = [:]
    @ObservationIgnored private var refill: Task<Void, Never>?
    private(set) var revision = 0

    private init() {}

    /// A row whose icon was evicted asks for it again, so an evicted icon never stays a placeholder.
    func image(for url: URL, isDirectory: Bool, pointSize: CGFloat = listPointSize) -> NSImage {
        _ = revision
        let key = cacheKey(for: url, pointSize: pointSize)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        scheduleRefill(url, pointSize: pointSize)
        return isDirectory
            ? Self.folderPlaceholder(pointSize: pointSize)
            : Self.documentPlaceholder(pointSize: pointSize)
    }

    func prefetch(_ urls: [URL], pointSize: CGFloat = listPointSize) async {
        var sinceYield = 0
        for url in urls {
            if Task.isCancelled { return }
            let key = cacheKey(for: url, pointSize: pointSize) as NSString
            if cache.object(forKey: key) == nil {
                cache.setObject(makeIcon(for: url, pointSize: pointSize), forKey: key)
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

    private func scheduleRefill(_ url: URL, pointSize: CGFloat) {
        let key = cacheKey(for: url, pointSize: pointSize)
        missing[key] = (url, pointSize)
        guard refill == nil else { return }
        refill = Task {
            await Task.yield()
            let pending = Array(missing.values)
            missing = [:]
            refill = nil
            for item in pending {
                if Task.isCancelled { return }
                let cacheKey = cacheKey(for: item.url, pointSize: item.pointSize) as NSString
                if cache.object(forKey: cacheKey) == nil {
                    cache.setObject(makeIcon(for: item.url, pointSize: item.pointSize), forKey: cacheKey)
                }
            }
            if !pending.isEmpty {
                revision += 1
            }
        }
    }

    private func makeIcon(for url: URL, pointSize: CGFloat) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        let sized = (image.copy() as? NSImage) ?? image
        sized.size = NSSize(width: pointSize, height: pointSize)
        return sized
    }

    private func cacheKey(for url: URL, pointSize: CGFloat) -> String {
        "\(url.path)|\(Int(pointSize.rounded()))"
    }

    private static func folderPlaceholder(pointSize: CGFloat) -> NSImage {
        placeholder(named: NSImage.folderName, pointSize: pointSize)
    }

    private static func documentPlaceholder(pointSize: CGFloat) -> NSImage {
        placeholder(system: .data, pointSize: pointSize)
    }

    private static func placeholder(named name: NSImage.Name, pointSize: CGFloat) -> NSImage {
        let image = (NSImage(named: name)?.copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: pointSize, height: pointSize)
        return image
    }

    private static func placeholder(system type: UTType, pointSize: CGFloat) -> NSImage {
        let image = (NSWorkspace.shared.icon(for: type).copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: pointSize, height: pointSize)
        return image
    }
}
