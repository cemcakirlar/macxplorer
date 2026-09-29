# Review: Macxplorer file manager

Audit of 29 Sep 2026, with its resolution. It replaces the review of 27 Sep 2026. That review's code findings stayed fixed, and its manual pass is carried over below.

This doc gives no line or test counts, because they go stale. Run `make tests` for the current numbers.

## Status

Every confirmed finding is fixed. Each fix has a unit test where the logic can be tested without the UI, and each was also checked by hand in the running app.

| ID | Severity | Finding | Status | Commit |
| --- | --- | --- | --- | --- |
| F2 | High | A second alert replaced a collision alert, so the transfer hung and paste and drop stayed disabled until quit. | Fixed. `AlertPresenter` queues alerts, and each one owns its own continuation. | `668e802` |
| F13 | High | `build.sh` hid the `xcodebuild` exit status, so a failed build reported success and could package or install an old app. | Fixed. The script reads the status from `PIPESTATUS` and exits with it. | `e104155` |
| F1 | Hardening | The selection hold was a bare `Bool` that didn't record its folder. | Fixed. `SelectionHold` is keyed to the destination folder and clears on the next selection change. | `9133fdd` |
| N1 | Medium | Undo was bound once at `onAppear`, so a late or changed `UndoManager` left undo dead. | Fixed. It rebinds whenever the undo manager changes. | `9133fdd` |
| N2 | Medium | The Trash shortcut matched plain Delete. | Fixed. Only Command-Delete moves to the Trash, as in Finder. The Function flag that macOS adds to Delete is ignored. | `9133fdd` |
| F4 | Low | Sidebar rename checked names against an empty list. | Fixed. It reads the parent folder's names from disk. | `52178ee` |
| F5 | Low | The icon cache never evicted. | Fixed. `NSCache` with a count limit, and evicted icons are fetched again on demand. | `52178ee` |
| F11 | Low | Nested drops were deduped by a 400 ms window. | Fixed. They're deduped by the drag pasteboard's `changeCount`. | `52178ee` |
| F12 | Nit | The Quick Look pane went blank with no log. | Fixed. It logs an error. | `52178ee` |
| F7 | Low | This doc reported stale counts. | Fixed by this rewrite. | This commit |
| F9 | Medium | No tests covered the stateful code. | Fixed for the new logic: the alert queue, selection hold, Trash shortcut, drop claim, and protected folders. | Phases 1–3 |
| F8 | Medium | No CI. | Dropped by decision. Tests run locally with `make tests`. | `25b32e7` |
| F10 | Structure | `FileEditing` had five jobs, and the undo relays lived in a Views file. | Fixed. It's split into rename, trash, and transfer coordinators, with `UndoRelays.swift` and one shared `CoordinatedOutcome`. Behavior is unchanged. | Phase 5 |

## Found while testing by hand

| Finding | Status | Commit |
| --- | --- | --- |
| Sidebar selection turned gray, and Command-Delete did nothing in the tree, because the rename click layer took the click without focusing the table. | Fixed. A click focuses the table first. | `9133fdd` |
| Return didn't start a rename in the sidebar, because the first focus request was dropped. | Fixed. Focus is requested again after one turn. | `9133fdd` |
| The home folder, other users' folders, `Shared`, standard home folders, and system folders could be renamed, trashed, or moved. | Fixed. `ProtectedFolders` refuses rename (with a beep), trash, and move. Copying still works. | `52178ee` |
| Move to Trash didn't ask first. | Fixed. It asks every time, and Escape cancels. | `52178ee` |

## Dropped findings

These were checked and found wrong, or not worth changing:

- **F3**, check-then-trash in transfers. Both calls already run inside the `NSFileCoordinator` block.
- **F6**, the `UserDefaults` write on every navigation. It doesn't block on disk, and debouncing it would lose the last folder on a crash.
- **Nits:** the `keepBothName` bound always ends. The nested `Task` in `createNewFolder` is intentional. `fatalError` in `init(coder:)` is the standard pattern. Path-bar width caching would save only about 10 measurements.

## Carried over from 27 Sep 2026

Fixed then and still in place: Terminal opens through `NSWorkspace`, not AppleScript. There is one click catcher per row. Icons prefetch off the first render. Directory reads cancel. Path identity has tests.

Still open is the four-click manual pass, about 2 minutes:

1. Expand Home with its disclosure triangle. Subfolders appear, and the UI stays responsive.
2. Double-click a folder in the Name column. The list and the sidebar both show that folder.
3. Double-click a file. It opens in its default app.
4. Press Terminal on a normal folder. A Terminal window opens there.

## FYI

- Ad-hoc signing turns the hardened runtime off at signing time, even with `ENABLE_HARDENED_RUNTIME = YES`. A Developer ID build would keep it on.
- App Sandbox is off by design.
- There's a stray `DerivedData/` folder at the repo root, which is gitignored. The scripts use `.build/DerivedData`. Deleting it needs the owner's OK.
