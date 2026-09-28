import AppKit
import SwiftUI

struct RenameSession: Equatable {
    var url: URL
    var isFolder: Bool
    var draft: String
    var extensionChangeConfirmed = false
}

struct RenameEditing {
    var session: RenameSession?
    var draft: Binding<String>
    var refocusID: Int
    var commit: () -> Void
    var cancel: () -> Void
    var begin: (URL) -> Void
}

struct InlineRenameField: View {
    @Binding var draft: String
    var isFolder: Bool
    var refocusID: Int
    var onCommit: () -> Void
    var onCancel: () -> Void

    @FocusState private var focused: Bool
    @State private var selection: TextSelection?
    @State private var cancelled = false

    var body: some View {
        TextField("Name", text: $draft, selection: $selection)
            .textFieldStyle(.plain)
            .focused($focused)
            .onAppear(perform: focusSelectingName)
            .onChange(of: refocusID) { _, _ in
                cancelled = false
                focusSelectingName()
            }
            .onSubmit(onCommit)
            .onExitCommand {
                cancelled = true
                onCancel()
            }
            .onKeyPress(.escape) {
                cancelled = true
                onCancel()
                return .handled
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused, !cancelled {
                    onCommit()
                }
            }
    }

    private func focusSelectingName() {
        let prefix = RenameName.selectedPrefix(in: draft, isFolder: isFolder)
        let end = draft.index(draft.startIndex, offsetBy: prefix.count, limitedBy: draft.endIndex) ?? draft.endIndex
        selection = TextSelection(range: draft.startIndex..<end)
        focused = true
    }
}

struct RenameClickCatcher: NSViewRepresentable {
    var isSelected: Bool
    var onSlowClick: @MainActor () -> Void
    var onDoubleClick: (@MainActor () -> Void)?

    func makeNSView(context: Context) -> RenameClickView {
        let view = RenameClickView()
        view.isSelected = isSelected
        view.onSlowClick = onSlowClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: RenameClickView, context: Context) {
        nsView.isSelected = isSelected
        nsView.onSlowClick = onSlowClick
        nsView.onDoubleClick = onDoubleClick
        if !isSelected {
            nsView.cancelPendingClick()
        }
    }
}

final class RenameClickView: NSView {
    var isSelected = false
    var onSlowClick: (@MainActor () -> Void)?
    var onDoubleClick: (@MainActor () -> Void)?
    private var timer: Timer?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            cancelPendingClick()
            let action = onDoubleClick
            if let action {
                Task { @MainActor in
                    action()
                }
            }
        } else if event.clickCount == 1, isSelected {
            cancelPendingClick()
            let delay = NSEvent.doubleClickInterval
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.timer = nil
                    self.onSlowClick?()
                }
            }
        }
        nextResponder?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        cancelPendingClick()
        nextResponder?.mouseDragged(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            cancelPendingClick()
        }
    }

    func cancelPendingClick() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
final class RenameUndoRelay {
    var perform: ((URL, String) async -> Bool)?

    func register(undoManager: UndoManager?, from oldURL: URL, to newURL: URL) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { relay in
            let previousName = oldURL.lastPathComponent
            let currentURL = newURL
            Task { @MainActor in
                let succeeded = await relay.perform?(currentURL, previousName) ?? false
                if succeeded {
                    relay.register(undoManager: undoManager, from: currentURL, to: oldURL)
                } else {
                    relay.register(undoManager: undoManager, from: oldURL, to: newURL)
                }
            }
        }
        undoManager.setActionName("Rename")
    }
}

enum TrashShortcut {
    static func matches(_ modifiers: EventModifiers) -> Bool {
        modifiers.subtracting([.capsLock, .command]).isEmpty
    }
}

@MainActor
final class TrashUndoRelay {
    /// Puts items back. Returns the ones that stayed in the Trash.
    var putBack: (([TrashedItem]) async -> [TrashedItem])?

    func register(undoManager: UndoManager?, items: [TrashedItem]) {
        guard let undoManager, !items.isEmpty else { return }
        undoManager.registerUndo(withTarget: self) { relay in
            let pending = items
            Task { @MainActor in
                let remaining = await relay.putBack?(pending) ?? pending
                if !remaining.isEmpty {
                    relay.register(undoManager: undoManager, items: remaining)
                }
            }
        }
        undoManager.setActionName("Move to Trash")
    }
}

@MainActor
final class NewFolderUndoRelay {
    var undo: ((URL, CreatedFolderIdentity) async -> Void)?

    func register(undoManager: UndoManager?, folder: URL, identity: CreatedFolderIdentity) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { relay in
            let created = folder
            let createdIdentity = identity
            Task { @MainActor in
                await relay.undo?(created, createdIdentity)
            }
        }
        undoManager.setActionName("New Folder")
    }
}

final class CreatedFolderIdentity: @unchecked Sendable {
    let value: NSObject?

    init(_ value: NSObject?) {
        self.value = value
    }
}
