import SwiftUI

/// Shared loading / error / empty shell for Details, Icons, and Columns.
struct FileBrowseChrome<Content: View>: View {
    var model: BrowserModel
    var nameFilter: String = ""
    var onClearFilter: (() -> Void)? = nil
    var receiveDrop: ([URL], DropTargetKind, Bool) -> Void
    @ViewBuilder var content: () -> Content

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], delegate: FileDropDelegate(target: openFolderTarget, receive: receiveDrop))
            } else if FileNameFilter.filtered(model.entries, query: nameFilter).isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("No items match “\(nameFilter.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                    )
                    if let onClearFilter {
                        Button("Clear Search", action: onClearFilter)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content()
            }
        }
    }

    private var openFolderTarget: DropTargetKind {
        guard let url = model.selectedURL else { return .missing }
        return .folder(url)
    }
}
