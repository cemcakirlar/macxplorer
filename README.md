# Macxplorer

Native macOS file manager: folder tree on the left, file list on the right. Subfolders load when you expand them. App Sandbox is off so the app can read your disk.

## Run in Xcode

1. Open `Macxplorer.xcodeproj`.
2. Scheme **Macxplorer**, then Run (Command-R).
3. If macOS asks, allow Desktop, Documents, and Downloads.
4. For protected folders such as `~/Library`, grant Full Disk Access: System Settings → Privacy & Security → Full Disk Access, then enable Macxplorer.

Sandbox is already off (`ENABLE_APP_SANDBOX = NO` and `Macxplorer/Macxplorer.entitlements`). Full Disk Access is a system toggle, not an entitlement.

## Try it

1. Expand **Home** with the chevron. Only that folder’s subfolders load.
2. Click a folder. The list shows Name, Date Modified, Size, and Kind. Folders are first, then files.
3. Double-click a folder. The list opens it and the sidebar expands to the same path.
4. Double-click a file. It opens in the default app.
5. Use the path bar to jump upward. **Hidden** (Command-Shift-.), **Refresh** (Command-R), **Finder**, and **Terminal** are in the toolbar.

Directory size stays “—”. Folder sizes are not calculated.
