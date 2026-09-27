import Foundation
import Observation

@MainActor
@Observable
final class FolderNode: Identifiable {
    enum LoadState: Equatable {
        case unloaded
        case loading
        case loaded
        case failed(String)

        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    nonisolated let url: URL
    nonisolated let name: String
    var children: [FolderNode] = []
    var loadState: LoadState = .unloaded

    nonisolated var id: URL { url }

    init(url: URL, name: String) {
        self.url = url.directoryKey
        self.name = name
    }
}
