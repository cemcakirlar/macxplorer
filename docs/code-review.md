# Review: Macxplorer file manager

Reviewed 27 Sep 2026 against the Macxplorer plan. Working tree, not a commit. No third-party dependencies.

## Resolution

Code findings from this review are fixed. `xcodebuild test` on 27 Sep 2026 ran 5 tests, 0 failures. The four-click pass is still open.

| Finding | Status |
| --- | --- |
| Terminal AppleScript | Fixed. `NSWorkspace` opens Terminal.app with the folder URL. A failure shows an alert and does not clear the file list. |
| Four-click pass | Open. Chevron, Name-column double-click, file open, and Terminal still need a manual run. |
| Four click-catchers per row | Fixed. The catcher is on the Name column only. |
| Main-thread icon fetch | Fixed. Rows show a placeholder, then `IconStore.prefetch` fills real icons in batches of 24. |
| Detached read ignores cancel | Fixed. `listDirectory` cancels its detached task and checks cancellation every 64 metadata reads. `contentsOfDirectory` itself still cannot be interrupted. |
| Untested path identity | Fixed. `FolderRoutingTests` covers `directoryKey`, the chain from `/` and from a synthetic home, and `/Volumes` over `/`. |
| `let _ = model.expanded` | Fixed as `trackExpansion()`. The read stays, because programmatic expand would not refresh the row without it. |
| Hardened runtime, sandbox, dead code | Unchanged, as noted. |

### Context

- [x] I understand what this change does and why

A sandboxed-off SwiftUI file manager: lazy folder tree, metadata table, filesystem work off the main thread.

### Correctness

- [x] Change matches spec/task requirements
- [x] Edge cases handled
- [x] Error paths handled
- [x] Tests cover the change adequately

The plan’s structure is in place: `DisclosureGroup` tree, Home / Root / Volumes, one-level fetches, packages treated as files, folder size `"—"`, columns Name / Date Modified / Size / Kind, path bar, hidden toggle, Finder, Terminal, sidebar width 180 / 240 / 480.

Terminal opens the current folder through `NSWorkspace` and Terminal.app. The path stays a URL. If opening fails, an alert shows the error. That failure is not written to `detailError`, so a populated folder stays on screen.

### Readability

- [x] Names are clear and consistent
- [x] Logic is straightforward
- [x] No unnecessary complexity

`BrowserModel` is the orchestration point. Path identity lives in `FolderRouting`. Sidebar expansion still reads `model.expanded` from `trackExpansion()`, because `DisclosureGroup` reads its binding outside `body`.

### Architecture

- [x] Follows existing patterns
- [x] No unnecessary coupling or dependencies
- [x] Appropriate abstraction level
- [x] Refactors reduce complexity rather than relocate it
- [x] No feature logic in shared modules; file stays within a healthy size

Views call `BrowserModel`. The model calls `FileSystemService`. `FileSystemService` returns `FileEntry` values and does not touch `FolderNode`. No new packages. Largest file is `BrowserModel.swift` (205 lines). Swift sources together are under 800 lines, one feature, fine as a single change.

### Security

- [x] No secrets in code
- [x] Input validated at boundaries
- [x] No injection vulnerabilities
- [x] Auth checks in place
- [x] External data sources treated as untrusted

Sandbox off is what the plan requires. Full Disk Access is not an entitlement. Privacy strings for Desktop, Documents, Downloads, and volumes are in `Info.plist`. No secrets, no network. Finder and Terminal both go through `NSWorkspace`, so a folder name is never pasted into a script.

**FYI:** ad-hoc signing turns hardened runtime off at codesign time even though `ENABLE_HARDENED_RUNTIME` is YES. Expected for local Run. A Developer ID build would keep it.

### Performance

- [x] No N+1 patterns
- [ ] No unbounded operations
- [x] Pagination on list endpoints

One `contentsOfDirectory` per expand or selection. Cancelling the detail task cancels the detached read; the listing call itself still runs to completion. Icons prefetch in batches of 24 after the rows are allowed to appear. Double-click uses one `NSView` on the Name column.

### Verification

- [x] Tests pass
- [x] Build succeeds
- [ ] Manual verification done (if applicable)

`xcodebuild -project Macxplorer.xcodeproj -scheme Macxplorer -destination 'platform=macOS' test` succeeded. 5 tests, 0 failures (`FileSystemSortTests`, `FolderRoutingTests`). The test host launched the app.

Still to do in the running app, about 2 minutes:

1. Expand Home with the chevron. Subfolders appear, and the UI stays responsive.
2. Double-click a folder in the Name column. The list and the sidebar show that folder.
3. Double-click a file. It opens in the default app.
4. Press Terminal on a normal folder. A Terminal window opens there. If it fails, an alert shows the error.

### Verdict

- [ ] **Approve** — Ready to merge
- [x] **Request changes** — The four-click pass is still open

Code findings are fixed. Merge still waits on the manual clicks in Verification.

### Findings

| Severity | Where | Finding | Status |
| --- | --- | --- | --- |
| Required | `ContentView.openInTerminal` | Path was interpolated into AppleScript, and errors were ignored. | Fixed. `NSWorkspace` plus an alert. |
| Required | Verification | Chevron, double-click, and Terminal were not exercised. | Open. |
| Consider | `FileListView` | Four `NSView` overlays per row. | Fixed. Name column only. |
| Consider | `IconStore` | First icon fetch blocked the main thread. | Fixed. Placeholder, then prefetch in batches of 24. |
| Consider | `FileSystemService.listDirectory` | Parent cancel did not stop the detached read. | Fixed. Detached task is cancelled; metadata loop checks every 64 items. |
| Consider | Path identity | `directoryKey` and the ancestor chain were untested. | Fixed. `FolderRoutingTests`. |
| Nit | `SidebarTreeView` | Discarded `model.expanded` read. | Fixed. `trackExpansion()` keeps the read on purpose. |
| FYI | Signing | Hardened runtime is off for ad-hoc signatures. | No change. |
| FYI | Entitlements | Sandbox off is the plan. | No change. |
| FYI | Dead code | None found. | Nothing to delete. |
