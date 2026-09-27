import AppKit
import SwiftUI

struct SidebarTreeView: View {
    var model: BrowserModel

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: selection) {
                ForEach(model.roots) { node in
                    SidebarBranch(model: model, node: node)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Folders")
            .onChange(of: model.scrollToURL) { _, url in
                guard let url else { return }
                Task { @MainActor in
                    proxy.scrollTo(url, anchor: .center)
                }
            }
        }
    }

    private var selection: Binding<URL?> {
        Binding(
            get: { model.selectedURL },
            set: { url in
                guard let url else { return }
                model.select(url)
            }
        )
    }
}

private struct SidebarBranch: View {
    var model: BrowserModel
    var node: FolderNode

    var body: some View {
        // Access the set in body so this row refreshes when expansion changes.
        let _ = model.expanded
        Group {
            if node.loadState == .loaded, node.children.isEmpty {
                rowLabel
            } else {
                DisclosureGroup(isExpanded: expansion) {
                    branchContent
                } label: {
                    rowLabel
                }
            }
        }
        .tag(node.url)
        .id(node.url)
    }

    private var rowLabel: some View {
        HStack(spacing: 6) {
            Image(nsImage: IconStore.shared.icon(for: node.url))
                .resizable()
                .frame(width: 16, height: 16)
            Text(node.name)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var branchContent: some View {
        switch node.loadState {
        case .unloaded, .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        case .loaded:
            ForEach(node.children) { child in
                SidebarBranch(model: model, node: child)
            }
        }
    }

    private var expansion: Binding<Bool> {
        Binding(
            get: { model.expanded.contains(node.url) },
            set: { newValue in
                if newValue {
                    model.expanded.insert(node.url)
                    if node.loadState == .unloaded || node.loadState.isFailed {
                        Task { await model.loadChildren(of: node) }
                    }
                } else {
                    model.expanded.remove(node.url)
                }
            }
        )
    }

}
