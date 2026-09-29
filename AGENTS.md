# MacXplorer

SwiftUI macOS file manager. Project `Macxplorer.xcodeproj`, scheme `Macxplorer`. App Sandbox is off.

## Build surface

`make` at the repo root is how this repo compiles, tests, launches, quits, logs, packages, installs, cleans, and releases. Run `make` or `make help` for the menu. Target names live in the Makefile; look them up there.

Each `scripts/*.sh` file implements a target. Run the target. Run the script only when you need a flag no target forwards; that script's `--help` lists the flags.

Done when the `make` process exits 0. For `make run`, the script also prints a running PID, or tells you to check the window.

### Which target

- Debug compile, then stop: `make build`. Release compile, then stop: `make release`.
- Show the window after a change: `make run`. It quits any running Macxplorer, builds Debug, and opens the app.
- Read process stdout: `make run-fg`.
- Quit the app: `make stop`.
- Stream unified logs for subsystem `com.cakirlarc.macxplorer`: `make logs`. Ctrl+C ends the stream.
- Zip and checksum under `dist/`: `make package`.
- Replace `/Applications/Macxplorer.app`: `make install`, and only when the user asked to install.
- Delete this project's DerivedData: `make clean`.

### Release

The default bump is patch: `make release-patch`. Use `make release-minor` or `make release-major` only when the user named that bump. An exact version is `make release-publish VERSION=X.Y.Z`.

A real release refuses a dirty worktree, then bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj`, writes `CHANGELOG.md` from Conventional Commits, packages a Release build, commits, tags, pushes, and publishes a GitHub Release. Rehearse with `make release-dry-run` before a real release. Leave those version fields and `CHANGELOG.md` to that target.

### Tests

Run the unit tests with `make tests`. It uses the same project, scheme, and DerivedData as the build script. It prints failures and the test count, and writes the full xcodebuild output to `.build/test.log`.

Done when `make tests` exits 0.

### Product path

Products land in `.build/DerivedData/Build/Products/<Debug|Release>/Macxplorer.app`. `make run` launches that bundle. A build that uses another DerivedData path is a different app.
