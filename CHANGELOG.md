# Changelog

All notable changes to Macxplorer will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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


