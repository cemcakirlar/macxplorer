import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileDropDelegate: DropDelegate {
    var target: DropTargetKind
    var receive: ([URL], DropTargetKind, Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        switch target {
        case .file, .missing:
            return DropProposal(operation: .forbidden)
        case .folder:
            let copies = NSEvent.modifierFlags.contains(.option)
            return DropProposal(operation: copies ? .copy : .move)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
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
