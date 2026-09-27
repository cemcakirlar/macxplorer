import SwiftUI

struct PathBarView: View {
    var url: URL?
    var onSelect: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let url {
                    let parts = components(of: url)
                    ForEach(parts) { part in
                        Button(part.name) {
                            onSelect(part.url)
                        }
                        .buttonStyle(.plain)
                        .fontWeight(part.url.path == url.directoryKey.path ? .semibold : .regular)
                        if part.id != parts.last?.id {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No Folder")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func components(of url: URL) -> [PathComponent] {
        let start = url.directoryKey
        var chain: [URL] = []
        var current = start
        while true {
            chain.append(current)
            let parent = current.deletingLastPathComponent().directoryKey
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return chain.reversed().map { item in
            PathComponent(
                url: item,
                name: FileManager.default.displayName(atPath: item.path)
            )
        }
    }
}

private struct PathComponent: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    let name: String
}
