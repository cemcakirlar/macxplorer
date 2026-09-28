import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Light accent pill. Same corner and insets as a selected row, lighter so it stays a drop target.
struct DropTargetHighlight: View {
    enum Edge {
        case all
        case sidebar
        case leading
        case middle
        case trailing
    }

    var edge: Edge = .all

    var body: some View {
        shape
            .fill(Color.accentColor.opacity(0.35))
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.vertical, verticalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var leadingInset: CGFloat {
        switch edge {
        case .all, .leading: return 6
        case .sidebar, .middle, .trailing: return 0
        }
    }

    private var trailingInset: CGFloat {
        switch edge {
        case .all, .sidebar, .trailing: return 6
        case .leading, .middle: return 0
        }
    }

    private var verticalInset: CGFloat {
        edge == .sidebar ? 1 : 2
    }

    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = 6
        switch edge {
        case .all, .sidebar:
            return UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: radius,
                bottomTrailingRadius: radius,
                topTrailingRadius: radius,
                style: .continuous
            )
        case .leading:
            return UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: radius,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        case .middle:
            return UnevenRoundedRectangle(style: .continuous)
        case .trailing:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: radius,
                topTrailingRadius: radius,
                style: .continuous
            )
        }
    }
}

enum DropHover {
    /// Marks `folder` while the pointer is over it, and clears only that same folder on exit.
    static func update(_ hovered: inout URL?, folder: URL, hovering: Bool) {
        if hovering {
            hovered = folder
            return
        }
        guard let current = hovered, Favorites.key(for: current) == Favorites.key(for: folder) else { return }
        hovered = nil
    }

    static func contains(_ hovered: URL?, folder: URL) -> Bool {
        guard let hovered else { return false }
        return Favorites.key(for: hovered) == Favorites.key(for: folder)
    }
}

/// Keeps one folder highlighted while the pointer crosses several drop targets on the same row.
struct DropHoverTracker {
    private(set) var url: URL?
    private var depth = 0
    private var epoch = 0

    mutating func enter(_ folder: URL) {
        epoch += 1
        if !DropHover.contains(url, folder: folder) {
            depth = 0
        }
        depth += 1
        url = folder
    }

    /// `nil` while another target on this folder is still under the pointer.
    mutating func exit(_ folder: URL) -> Int? {
        guard DropHover.contains(url, folder: folder) else { return nil }
        depth = max(0, depth - 1)
        guard depth == 0 else { return nil }
        return epoch
    }

    mutating func clearIfUnchanged(epoch captured: Int, folder: URL) {
        guard captured == epoch, depth == 0, DropHover.contains(url, folder: folder) else { return }
        url = nil
    }
}

struct FileDropDelegate: DropDelegate {
    var target: DropTargetKind
    var receive: ([URL], DropTargetKind, Bool) -> Void
    var onHover: ((Bool) -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        guard case .folder = target else { return }
        onHover?(true)
    }

    func dropExited(info: DropInfo) {
        guard case .folder = target else { return }
        onHover?(false)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let optionPressed = NSEvent.modifierFlags.contains(.option)
        switch DropDecision.cursor(
            target: target,
            optionPressed: optionPressed,
            sameVolume: sameVolumeAsDraggedFiles()
        ) {
        case .forbidden:
            return DropProposal(operation: .forbidden)
        case .copy:
            return DropProposal(operation: .copy)
        case .move:
            return DropProposal(operation: .move)
        }
    }

    private func sameVolumeAsDraggedFiles() -> Bool? {
        guard case .folder(let destination) = target else { return nil }
        let urls = FileDrag.urlsOnDragPasteboard()
        guard !urls.isEmpty else { return nil }
        let sameVolume = FileTransfer.Operations.live.sameVolume
        return urls.allSatisfy { sameVolume($0, destination) }
    }

    func performDrop(info: DropInfo) -> Bool {
        onFinish?()
        guard DropClaim.shared.claim() else { return true }
        let optionPressed = NSEvent.modifierFlags.contains(.option)
        switch target {
        case .file, .missing:
            return true
        case .folder:
            let providers = ProviderBox(info.itemProviders(for: [.fileURL]))
            let target = target
            let receive = UncheckedDrop(receive)
            Task {
                let urls = await FileDrag.urls(from: providers.items)
                await MainActor.run {
                    receive.call(urls, target, optionPressed)
                }
            }
            return true
        }
    }
}

final class UncheckedDrop: @unchecked Sendable {
    let call: ([URL], DropTargetKind, Bool) -> Void

    init(_ call: @escaping ([URL], DropTargetKind, Bool) -> Void) {
        self.call = call
    }
}

final class ProviderBox: @unchecked Sendable {
    let items: [NSItemProvider]

    init(_ items: [NSItemProvider]) {
        self.items = items
    }
}

final class DropClaim: @unchecked Sendable {
    static let shared = DropClaim()
    private let lock = NSLock()
    private var claimedAt = Date.distantPast

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if now.timeIntervalSince(claimedAt) < 0.4 {
            return false
        }
        claimedAt = now
        return true
    }
}
