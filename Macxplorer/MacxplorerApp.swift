import os
import SwiftUI

let appLogger = Logger(subsystem: "com.cakirlarc.macxplorer", category: "app")

@main
struct MacxplorerApp: App {
    init() {
        appLogger.info("MacXplorer started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: .shared)
        }
        .defaultSize(width: 1100, height: 700)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .pasteboard) {
                CutCommand()
                CopyCommand()
                PasteCommand()
                MoveItemHereCommand()
                SelectAllCommand()
            }
            CommandGroup(after: .pasteboard) {
                CopyPathCommand()
                NewFolderCommand()
            }
        }

        Settings {
            SettingsView(settings: .shared)
        }
    }
}

private struct CutCommand: View {
    @FocusedValue(\.fileEditAction) private var fileEditAction

    var body: some View {
        Button("Cut") {
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("x", modifiers: .command)
        .disabled(fileEditAction?.textEditing != true)
    }
}

private struct CopyCommand: View {
    @FocusedValue(\.fileCopyAction) private var fileCopyAction
    @FocusedValue(\.fileEditAction) private var fileEditAction

    var body: some View {
        Button("Copy") {
            if fileEditAction?.textEditing == true {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            } else if let urls = fileCopyAction?.urls, !urls.isEmpty {
                FilePasteboard.write(urls)
                fileEditAction?.notePasteboardChange()
            }
        }
        .keyboardShortcut("c", modifiers: .command)
        .disabled(fileEditAction?.textEditing != true && (fileCopyAction?.urls.isEmpty != false))
    }
}

private struct PasteCommand: View {
    @FocusedValue(\.fileEditAction) private var fileEditAction

    var body: some View {
        Button("Paste") {
            if fileEditAction?.textEditing == true {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            } else {
                fileEditAction?.pasteFiles()
            }
        }
        .keyboardShortcut("v", modifiers: .command)
        .disabled(fileEditAction?.textEditing != true && fileEditAction?.canPasteFiles != true)
    }
}

private struct MoveItemHereCommand: View {
    @FocusedValue(\.fileEditAction) private var fileEditAction

    var body: some View {
        Button("Move Item Here") {
            fileEditAction?.moveFiles()
        }
        .keyboardShortcut("v", modifiers: [.command, .option])
        .disabled(fileEditAction?.textEditing == true || fileEditAction?.canPasteFiles != true)
    }
}

private struct SelectAllCommand: View {
    var body: some View {
        Button("Select All") {
            NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("a", modifiers: .command)
    }
}

private struct CopyPathCommand: View {
    @FocusedValue(\.copyPathAction) private var copyPathAction

    var body: some View {
        Button("Copy Path") {
            copyPathAction?.perform()
        }
        .keyboardShortcut("c", modifiers: [.command, .option])
        .disabled(copyPathAction?.isEnabled != true)
    }
}

private struct NewFolderCommand: View {
    @FocusedValue(\.newFolderAction) private var newFolderAction

    var body: some View {
        Button("New Folder") {
            newFolderAction?.perform()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(newFolderAction?.isEnabled != true)
    }
}
