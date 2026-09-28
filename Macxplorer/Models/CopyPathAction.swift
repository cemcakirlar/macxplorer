import SwiftUI

struct CopyPathAction {
    var isEnabled: Bool
    var perform: () -> Void
}

private struct CopyPathActionKey: FocusedValueKey {
    typealias Value = CopyPathAction
}

extension FocusedValues {
    var copyPathAction: CopyPathAction? {
        get { self[CopyPathActionKey.self] }
        set { self[CopyPathActionKey.self] = newValue }
    }

    var newFolderAction: NewFolderAction? {
        get { self[NewFolderActionKey.self] }
        set { self[NewFolderActionKey.self] = newValue }
    }
}

struct NewFolderAction {
    var isEnabled: Bool
    var perform: () -> Void
}

private struct NewFolderActionKey: FocusedValueKey {
    typealias Value = NewFolderAction
}
