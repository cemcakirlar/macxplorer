# MacXplorer

Native macOS file manager: folder tree on the left, file list on the right. Subfolders load when you expand them. App Sandbox is off so the app can read your disk.

## Run in Xcode

1. Open `Macxplorer.xcodeproj`.
2. Scheme **Macxplorer**, then Run (Command-R).
3. If macOS asks, allow Desktop, Documents, and Downloads.
4. For protected folders such as `~/Library`, grant Full Disk Access: System Settings → Privacy & Security → Full Disk Access, then enable MacXplorer.

Sandbox is already off (`ENABLE_APP_SANDBOX = NO` and `Macxplorer/Macxplorer.entitlements`). Full Disk Access is a system toggle, not an entitlement.

## Commands

`make help` lists every command.

- `make run` builds Debug and opens the window.
- `make run-fg` runs that build in the terminal.
- `make build` compiles Debug only. `make release` compiles Release only.
- `make logs` streams the running app’s system log. `Ctrl+C` stops it.
- `make stop` quits the running app.
- `make package` writes `dist/Macxplorer-v<version>-macOS.zip`.
- `make install` builds Release and copies the app to `/Applications`.
- `make clean` removes DerivedData for this project.
- `make release-patch` is the default release (changelog, tag, GitHub Release). Use `release-minor` or `release-major` only when you mean that bump. `make release-dry-run` rehearses the same steps.

## Try it

1. Expand **Home** with the chevron. Only that folder’s subfolders load.
2. Click a folder. The list shows Name, Date Modified, Size, and Kind. Click a column header to sort. Name sort keeps folders first.
3. Double-click a folder. The list opens it and the sidebar expands to the same path.
4. Double-click a file. It opens in the default app.
5. Use the path bar to jump upward. **Back** (Command-[), **Forward** (Command-]), and **Up** (Command-Up Arrow) sit at the leading edge of the toolbar.
6. **Hidden** (Command-Shift-.), **Refresh** (Command-R), **Preview** (Command-Shift-P), **Finder**, and **Terminal** are in the toolbar. Preview uses Quick Look and shows kind, size, and modified date for the selected item.
7. Right-click a file or folder: **Reveal in Finder**, **Open in Terminal**, **Copy Name**, **Copy Path**, **Copy Path with ~**, and **Quick Look**. **Copy Path** is also Option-Command-C. If nothing in the list is selected, the shortcut copies the open folder. A file’s terminal is its parent folder. **Quick Look** opens the preview for that one item.

Directory size stays “—”. Folder sizes are not calculated.

## Settings

Open **Settings** (Command-,).

- **General:** show hidden files in the list, reopen the last folder, and choose the terminal app (Terminal, iTerm, Ghostty, Warp, or another app).
- **Preview:** play media automatically.
- **Sidebar:** show hidden folders, and rename the Home, Root, and Volumes labels.

## Open a downloaded build

This build is distributed outside the Mac App Store. Gatekeeper may say Apple could not verify the app.

1. Run `xattr -cr "/Applications/Macxplorer.app"`, or
2. Open **System Settings → Privacy & Security** and click **Open Anyway**.

## License

[MIT](LICENSE)
