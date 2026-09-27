import QuickLook
import QuickLookUI
import SwiftUI

struct PreviewInspector: View {
    var entries: [FileEntry]
    var selection: Set<URL>
    var autoplay: Bool

    var body: some View {
        Group {
            if selection.isEmpty {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc",
                    description: Text("Choose an item in the list.")
                )
            } else if selection.count > 1 {
                ContentUnavailableView(
                    "\(selection.count) Items Selected",
                    systemImage: "square.stack",
                    description: Text("Select one item to preview it.")
                )
            } else if let url = selection.first {
                selectedPreview(url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectedPreview(_ url: URL) -> some View {
        VStack(spacing: 0) {
            QuickLookPreview(url: url, autoplay: autoplay)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let entry = entries.first(where: { $0.url == url }) {
                Divider()
                metadata(entry)
            }
        }
    }

    private func metadata(_ entry: FileEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.name)
                .font(.headline)
                .lineLimit(2)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                metadataRow("Kind", entry.kind)
                metadataRow("Size", FileMetadataFormat.sizeText(bytes: entry.size))
                metadataRow("Modified", FileMetadataFormat.dateText(entry.modified))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
        }
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    var url: URL
    var autoplay: Bool

    func makeNSView(context: Context) -> QuickLookHost {
        QuickLookHost(url: url, autoplay: autoplay)
    }

    func updateNSView(_ nsView: QuickLookHost, context: Context) {
        nsView.show(url, autoplay: autoplay)
    }
}

private final class QuickLookHost: NSView {
    private let preview: QLPreviewView?
    private var shownPath: String?

    init(url: URL, autoplay: Bool) {
        preview = QLPreviewView(frame: .zero, style: .normal)
        super.init(frame: .zero)
        guard let preview else { return }
        preview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(preview)
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: trailingAnchor),
            preview.topAnchor.constraint(equalTo: topAnchor),
            preview.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        show(url, autoplay: autoplay)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ url: URL, autoplay: Bool) {
        preview?.autostarts = autoplay
        guard shownPath != url.path else { return }
        shownPath = url.path
        preview?.previewItem = url as QLPreviewItem
    }
}
