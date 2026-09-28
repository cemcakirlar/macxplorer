import AppKit
import UniformTypeIdentifiers

enum FileDrag {
    static func provider(for urls: [URL]) -> NSItemProvider {
        let unique = deduplicated(urls)
        let provider = NSItemProvider()
        guard let first = unique.first else { return provider }
        provider.registerObject(first as NSURL, visibility: .all)
        provider.suggestedName = first.lastPathComponent
        let paths = unique.map(\.path)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: paths, format: .binary, options: 0) else {
            return provider
        }
        provider.registerDataRepresentation(forTypeIdentifier: filenamesType, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        if providers.count == 1, let many = await filenames(from: providers[0]), many.count > 1 {
            return deduplicated(many)
        }
        var found: [URL] = []
        for provider in providers {
            if let url = await fileURL(from: provider) {
                found.append(url)
            } else if let many = await filenames(from: provider) {
                found.append(contentsOf: many)
            }
        }
        return deduplicated(found)
    }

    private static let filenamesType = "NSFilenamesPboardType"

    private static func fileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            provider.loadObject(ofClass: NSURL.self) { object, _ in
                let url = (object as? URL).flatMap { $0.isFileURL ? $0 : nil }
                gate.resume(continuation, with: url)
            }
        }
    }

    private static func filenames(from provider: NSItemProvider) async -> [URL]? {
        let type = filenamesType
        guard provider.registeredTypeIdentifiers.contains(type) else { return nil }
        return await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                guard
                    let data,
                    let paths = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
                else {
                    gate.resume(continuation, with: nil)
                    return
                }
                gate.resume(continuation, with: paths.map { URL(fileURLWithPath: $0) })
            }
        }
    }

    private static func deduplicated(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert(Favorites.key(for: $0)).inserted }
    }

    private final class ResumeGate: @unchecked Sendable {
        private var resumed = false

        func resume(_ continuation: CheckedContinuation<URL?, Never>, with value: URL?) {
            finish(continuation, with: value)
        }

        func resume(_ continuation: CheckedContinuation<[URL]?, Never>, with value: [URL]?) {
            finish(continuation, with: value)
        }

        private func finish<T: Sendable>(_ continuation: CheckedContinuation<T, Never>, with value: T) {
            guard !resumed else { return }
            resumed = true
            continuation.resume(returning: value)
        }
    }
}
