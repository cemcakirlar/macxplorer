import SwiftUI

enum FolderTypeAhead {
    /// Handles a key press for list type-ahead. Returns `.handled` when the buffer changes.
    static func handle(
        _ press: KeyPress,
        renaming: Bool,
        searchFocused: Bool,
        buffer: inout TypeAheadBuffer,
        visibleRows: [FileEntry],
        selection: inout Set<URL>
    ) -> KeyPress.Result {
        guard !renaming, !searchFocused else { return .ignored }
        if press.modifiers.contains(.command)
            || press.modifiers.contains(.option)
            || press.modifiers.contains(.control)
        {
            return .ignored
        }

        if press.key == .escape {
            if buffer.text.isEmpty { return .ignored }
            buffer.clear()
            return .handled
        }

        if press.key == .delete || press.key == .deleteForward {
            if buffer.text.isEmpty { return .ignored }
            buffer.backspace()
            applySelection(buffer: buffer, visibleRows: visibleRows, selection: &selection)
            return .handled
        }

        let characters = press.characters.filter { character in
            character.isLetter || character.isNumber || character.isPunctuation || character == " "
        }
        guard !characters.isEmpty else { return .ignored }

        for character in characters {
            buffer.append(character)
        }
        applySelection(buffer: buffer, visibleRows: visibleRows, selection: &selection)
        return .handled
    }

    private static func applySelection(
        buffer: TypeAheadBuffer,
        visibleRows: [FileEntry],
        selection: inout Set<URL>
    ) {
        guard let match = FileNameFilter.firstPrefixMatch(in: visibleRows, buffer: buffer.text) else {
            return
        }
        selection = [match.url]
    }
}
