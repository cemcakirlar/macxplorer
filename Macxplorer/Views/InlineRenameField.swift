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
        // Inside the sidebar list the first request is dropped when Return opened the field.
        Task { @MainActor in
            await Task.yield()
            if !focused {
                focused = true
            }
        }
    }
}

struct RenameClickCatcher: NSViewRepresentable {
    var isSelected: Bool
    var onSlowClick: @MainActor () -> Void
    var onDoubleClick: (@MainActor () -> Void)?
    var onPrimaryClick: (@MainActor (NSEvent.ModifierFlags) -> Void)?
    var fileDragRow: URL?
    var fileDragSelection: [URL] = []

    func makeNSView(context: Context) -> RenameClickView {
        let view = RenameClickView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: RenameClickView, context: Context) {
        apply(to: nsView)
        if !isSelected {
            nsView.cancelPendingClick()
        }
    }

    private func apply(to view: RenameClickView) {
        view.isSelected = isSelected
        view.onSlowClick = onSlowClick
        view.onDoubleClick = onDoubleClick
        view.onPrimaryClick = onPrimaryClick
        view.fileDragRow = fileDragRow
        view.fileDragSelection = fileDragSelection
    }
}

struct FileDragSource: NSViewRepresentable {
    var row: URL
    var selection: [URL]
    var onPrimaryClick: (@MainActor (NSEvent.ModifierFlags) -> Void)?

    func makeNSView(context: Context) -> RenameClickView {
        let view = RenameClickView()
        view.fileDragRow = row
        view.fileDragSelection = selection
        view.onPrimaryClick = onPrimaryClick
        return view
    }

    func updateNSView(_ nsView: RenameClickView, context: Context) {
        nsView.fileDragRow = row
        nsView.fileDragSelection = selection
        nsView.onPrimaryClick = onPrimaryClick
    }
}

final class RenameClickView: NSView, NSDraggingSource {
    var isSelected = false
    var onSlowClick: (@MainActor () -> Void)?
    var onDoubleClick: (@MainActor () -> Void)?
    var onPrimaryClick: (@MainActor (NSEvent.ModifierFlags) -> Void)?
    var fileDragRow: URL?
    var fileDragSelection: [URL] = []
    private var timer: Timer?
    private var dragStart: NSPoint?
    private var dragged = false
    private var finishedListClick = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        focusEnclosingTable()
        dragged = false
        dragStart = convert(event.locationInWindow, from: nil)
        if event.clickCount >= 2 {
            cancelPendingClick()
            deliverClick(event.modifierFlags)
            let action = onDoubleClick
            if let action {
                Task { @MainActor in
                    action()
                }
            }
            return
        }
        if fileDragRow == nil {
            handClickToList(event)
            return
        }
        if event.clickCount == 1, isSelected {
            scheduleSlowClick()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        cancelPendingClick()
        guard event.clickCount < 2, let dragStart, let row = fileDragRow else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - dragStart.x, point.y - dragStart.y) >= 4 else { return }
        dragged = true
        self.dragStart = nil
        let urls = draggingURLs(primary: row)
        guard !urls.isEmpty else { return }
        if !isSelected {
            deliverClick([])
        }
        let session = beginDraggingSession(with: draggingItems(for: urls, at: point), event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        if !dragged, event.clickCount < 2, !finishedListClick {
            deliverClick(event.modifierFlags)
        }
        finishedListClick = false
        dragged = false
    }

    /// A favorite row has no file drag. The list underneath reorders it with `onMove`.
    private func handClickToList(_ event: NSEvent) {
        let wasSelected = isSelected
        let start = event.locationInWindow
        guard let table = enclosingTable() else {
            deliverClick(event.modifierFlags)
            if wasSelected { scheduleSlowClick() }
            finishedListClick = true
            return
        }
        let wasHidden = isHidden
        isHidden = true
        table.mouseDown(with: event)
        isHidden = wasHidden
        finishedListClick = true
        guard !pointerMoved(from: start), event.clickCount < 2 else { return }
        deliverClick(event.modifierFlags)
        if wasSelected { scheduleSlowClick() }
    }

    /// This view takes the click, so the table under it would otherwise never get keyboard focus.
    private func focusEnclosingTable() {
        guard let window, let table = enclosingTable(), window.firstResponder !== table else { return }
        window.makeFirstResponder(table)
    }

    private func enclosingTable() -> NSTableView? {
        var view = superview
        while let current = view {
            if let table = current as? NSTableView { return table }
            view = current.superview
        }
        return nil
    }

    private func pointerMoved(from start: NSPoint) -> Bool {
        guard let window else { return false }
        let end = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return hypot(end.x - start.x, end.y - start.y) >= 4
    }

    private func scheduleSlowClick() {
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

    private func deliverClick(_ flags: NSEvent.ModifierFlags) {
        let click = onPrimaryClick
        Task { @MainActor in
            click?(flags)
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move]
    }

    private func draggingURLs(primary: URL) -> [URL] {
        let primaryKey = Favorites.key(for: primary)
        let selected = fileDragSelection.contains { Favorites.key(for: $0) == primaryKey }
        return selected ? fileDragSelection : [primary]
    }

    private func draggingItems(for urls: [URL], at point: NSPoint) -> [NSDraggingItem] {
        urls.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            let origin = NSPoint(x: point.x - 16 + CGFloat(index) * 6, y: point.y - 16)
            item.setDraggingFrame(NSRect(origin: origin, size: icon.size), contents: icon)
            return item
        }
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

enum TrashShortcut {
    /// Delete and Forward Delete arrive with this bit set. SwiftUI deprecates `.function` for apps,
    /// but key events still carry it.
    static let functionKey = EventModifiers(rawValue: 1 << 6)

    /// The Function bit is ignored along with Caps Lock and the numeric pad.
    static func matches(_ modifiers: EventModifiers) -> Bool {
        modifiers.subtracting([.capsLock, functionKey, .numericPad]) == .command
    }
}
