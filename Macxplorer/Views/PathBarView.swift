import AppKit
import SwiftUI

struct PathBarView: View {
    var url: URL?
    var onSelect: (URL) -> Void

    var body: some View {
        GeometryReader { geo in
            bar(width: geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func bar(width: CGFloat) -> some View {
        if let url {
            let parts = components(of: url)
            let hiddenCount = hiddenPrefixCount(parts: parts, width: width)
            let shown = Array(parts.dropFirst(hiddenCount))
            HStack(spacing: 6) {
                Image(nsImage: IconStore.shared.image(for: url.directoryKey, isDirectory: true))
                    .resizable()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                if hiddenCount > 0 {
                    overflowMenu(Array(parts.prefix(hiddenCount)))
                    chevron
                }
                ForEach(shown) { part in
                    Button(part.name) {
                        onSelect(part.url)
                    }
                    .buttonStyle(.plain)
                    .lineLimit(1)
                    .fontWeight(part.url.path == url.directoryKey.path ? .semibold : .regular)
                    if part.id != shown.last?.id {
                        chevron
                    }
                }
            }
        } else {
            Text("No Folder")
                .foregroundStyle(.secondary)
        }
    }

    private func overflowMenu(_ parts: [PathComponent]) -> some View {
        Menu {
            ForEach(parts) { part in
                Button(part.name) {
                    onSelect(part.url)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Earlier folders")
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func hiddenPrefixCount(parts: [PathComponent], width: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return 0 }
        let available = width - Self.iconWidth - Self.spacing
        let widths = parts.enumerated().map { index, part in
            textWidth(part.name, bold: index == parts.count - 1)
        }
        return PathBarFit.hiddenPrefixCount(
            crumbWidths: widths,
            gap: Self.gap,
            limit: available,
            ellipsisWidth: Self.ellipsisWidth
        )
    }

    private func textWidth(_ name: String, bold: Bool) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: NSFont.systemFontSize,
            weight: bold ? .semibold : .regular
        )
        let text = ceil((name as NSString).size(withAttributes: [.font: font]).width)
        return text + 8
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

    private static let iconWidth: CGFloat = 16
    private static let spacing: CGFloat = 6
    private static let gap: CGFloat = 20
    private static let ellipsisWidth: CGFloat = 28
}

private struct PathComponent: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    let name: String
}
