import SwiftUI

struct FileCopyAction {
    var urls: [URL]
}

private struct FileCopyActionKey: FocusedValueKey {
    typealias Value = FileCopyAction
}

struct FileEditAction {
    var textEditing: Bool
    var canPasteFiles: Bool
    var pasteFiles: () -> Void
    var moveFiles: () -> Void
    var notePasteboardChange: () -> Void
}

private struct FileEditActionKey: FocusedValueKey {
    typealias Value = FileEditAction
}

extension FocusedValues {
    var fileCopyAction: FileCopyAction? {
        get { self[FileCopyActionKey.self] }
        set { self[FileCopyActionKey.self] = newValue }
    }

    var fileEditAction: FileEditAction? {
        get { self[FileEditActionKey.self] }
        set { self[FileEditActionKey.self] = newValue }
    }
}
