# Changelog

All notable changes to MacXplorer will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.5.0] - 2026-09-29

### Bug Fixes
- fix(drop): open the target and keep the sidebar (`5d27b12`)
- fix(transfer): put back an item when replace fails (`7278601`)
- fix(drop): show copy when the disk differs (`9b4ca9b`)
- fix(rename): change case without a temporary name (`922e914`)

### Maintenance & Tooling
- chore: record the drop target plan (`53d3ff7`)
- chore: record the review fix plan (`4ab736e`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 



## [v1.4.0] - 2026-09-28

### Features
- feat(files): paste and drop items into a folder (`e155532`)
- feat(transfer): copy or move files without deleting them (`f5b53d2`)
- feat(folder): create an untitled folder and rename it (`c1071d7`)
- feat(trash): move the selection to the Trash (`10e8b42`)
- feat(rename): rename one item inline (`e4ecc9c`)

### Maintenance & Tooling
- chore: plans (`04209be`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 



## [v1.3.0] - 2026-09-28

### Features
- feat(sidebar): add a Favorites section (`c7903ec`)

### Bug Fixes
- fix(sidebar): use the clicked folder's path (`e1b6ae6`)

### Maintenance & Tooling
- chore: upgrade project checks to Xcode 27 (`2196f5b`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 



## [v1.2.0] - 2026-09-28

### Features
- feat: add a context menu for files (`3d8cf99`)
- feat: open folder aliases in the browser (`9f110cf`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 



## [v1.1.0] - 2026-09-27

### Features
- feat: split settings into tabs (`693de1b`)
- feat: add a Quick Look preview pane (`b70a5dd`)
- feat: add history, sorting, and a fitting path bar (`223d68a`)

### Maintenance & Tooling
- docs: document shortcuts and settings (`0946c90`)
- chore: add About panel credits (`ee20c82`)
- build: require macOS 15 (`8e2c2f1`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 



## [v1.0.2] - 2026-09-27

### Features
- feat: add settings for hidden files and launch (`f9ef2e2`)

### Maintenance & Tooling
- chore: spell the app name MacXplorer (`9317436`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 



## [v1.0.1] - 2026-09-27

### Features
- feat: add the app icon (`035693b`)
- feat: log navigation for make logs (`bb9e55a`)

### Bug Fixes
- fix: open Terminal without AppleScript (`fb99aac`)

### Performance & Refactoring
- refactor: update log stream predicate for Macxplorer (`b531637`)
- perf: cancel listing reads and prefetch icons (`a1cd694`)

### Maintenance & Tooling
- chore: apply Xcode 26.6 recommended settings (`0c38207`)
- build: add make run and release commands (`6b5b314`)
- docs: add MIT license (`3264faa`)
- docs: record code review resolution (`9000a30`)

### Other Changes
- first commit (`ca76bd3`)

---

### macOS Installation & Gatekeeper Note
Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*"Apple could not verify..."*) on first launch.

**To open the app, run this single command in Terminal:**
```bash
xattr -cr "/Applications/Macxplorer.app"
```
*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* 
