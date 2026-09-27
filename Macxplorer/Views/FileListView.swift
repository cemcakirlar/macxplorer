import AppKit
import SwiftUI

struct FileListView: View {
    var model: BrowserModel
    @Binding var rowSelection: Set<URL>
    @State private var sortOrder = [KeyPathComparator(\FileEntry.name)]

    var body: some View {
        Group {
            if model.isLoadingDetail, model.entries.isEmpty, model.detailError == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detailError = model.detailError, model.entries.isEmpty {
                ContentUnavailableView(
                    "Can't Open Folder",
                    systemImage: "exclamationmark.triangle",
                    description: Text(detailError)
                )
            } else if model.entries.isEmpty {
                ContentUnavailableView(
                    "Empty Folder",
                    systemImage: "folder",
                    description: Text("This folder is empty.")
                )
            } else {
                table
            }
        }
    }

    private var rows: [FileEntry] {
        FileListOrder.sorted(model.entries, by: FileSort(order: sortOrder))
    }

    private var table: some View {
        Table(rows, selection: $rowSelection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { entry in
                nameCell(entry)
            }
            .width(min: 180, ideal: 280)

            TableColumn("Date Modified", value: \.modifiedColumn) { entry in
                plainCell {
                    Text(FileMetadataFormat.dateText(entry.modified))
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 140, ideal: 170)

            TableColumn("Size", value: \.sizeColumn) { entry in
                plainCell(alignment: .trailing) {
                    Text(FileMetadataFormat.sizeText(bytes: entry.size))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Kind", value: \.kind) { entry in
                plainCell {
                    Text(entry.kind)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 100, ideal: 140)
        }
    }

    private func nameCell(_ entry: FileEntry) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: IconStore.shared.image(for: entry.url, isDirectory: entry.opensAsFolder))
                .resizable()
                .frame(width: 16, height: 16)
            Text(entry.name)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RowDoubleClickCatcher {
                open(entry)
            }
        }
    }

    private func plainCell<Content: View>(
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func open(_ entry: FileEntry) {
        if entry.opensAsFolder {
            Task { await model.navigate(to: entry.url) }
        } else {
            NSWorkspace.shared.open(entry.url)
        }
    }
}

@MainActor
enum FileMetadataFormat {
    static func dateText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func sizeText(bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return byteCount.string(fromByteCount: bytes)
    }

    private static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct RowDoubleClickCatcher: NSViewRepresentable {
    var onDoubleClick: @MainActor () -> Void

    func makeNSView(context: Context) -> RowDoubleClickView {
        let view = RowDoubleClickView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: RowDoubleClickView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }
}

private final class RowDoubleClickView: NSView {
    var onDoubleClick: (@MainActor () -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let action = onDoubleClick
            Task { @MainActor in
                action?()
            }
        }
        nextResponder?.mouseDown(with: event)
    }
}
