.DEFAULT_GOAL := help
.PHONY: all run run-fg stop build release package release-patch release-minor release-major release-publish release-dry-run install logs clean help

all: help

# Compile and run the app in background (Debug)
run:
	@./scripts/run.sh

# Run the app in terminal foreground with live console logs
run-fg:
	@./scripts/run.sh --foreground

# Terminate running app instance
stop:
	@./scripts/stop.sh

# Compile in Debug mode
build:
	@./scripts/build.sh --debug

# Compile in Release mode
release:
	@./scripts/build.sh --release

# Compile Release build and package distribution archive (.zip & .sha256) under dist/
package:
	@./scripts/package.sh

# DEFAULT RELEASE = patch. Use release-minor / release-major only when explicitly requested.
# Release SemVer Patch version (Changelog, Tag, GH Release)
release-patch:
	@./scripts/release.sh patch

# Release SemVer Minor version (Changelog, Tag, GH Release) — not the default
release-minor:
	@./scripts/release.sh minor

# Release SemVer Major version (Changelog, Tag, GH Release) — not the default
release-major:
	@./scripts/release.sh major

# Release custom version or default patch (e.g. make release-publish VERSION=1.2.0)
release-publish:
	@./scripts/release.sh $(if $(VERSION),$(VERSION),patch)

# Simulate full release cycle without making permanent changes (defaults to patch)
release-dry-run:
	@./scripts/release.sh $(if $(VERSION),$(VERSION),patch) --dry-run

# Compile Release and install permanently into macOS /Applications
install:
	@./scripts/install.sh --release

# Stream live unified system logs
logs:
	@./scripts/logs.sh

# Clean build cache (DerivedData)
clean:
	@./scripts/build.sh --clean

# Help menu
help:
	@echo "Macxplorer - Developer and Release Commands:"
	@echo "  make (or make help)  : Show this help menu (Default)"
	@echo "  make run             : Build Debug and launch in background"
	@echo "  make run-fg          : Run in foreground with live console logs"
	@echo "  make stop            : Terminate running application instance"
	@echo "  make build           : Compile Debug configuration only"
	@echo "  make release         : Compile Release configuration only"
	@echo "  make package         : Build Release and package distribution archive (dist/)"
	@echo "  make release-patch   : DEFAULT release — SemVer patch (e.g. 1.0.0 -> 1.0.1)"
	@echo "  make release-minor   : Minor bump only when explicitly requested (e.g. 1.0.0 -> 1.1.0)"
	@echo "  make release-major   : Major bump only when explicitly requested (e.g. 1.0.0 -> 2.0.0)"
	@echo "  make release-publish : Release specified version (defaults to patch if VERSION unset)"
	@echo "  make release-dry-run : Simulate full release cycle (defaults to patch)"
	@echo "  make install         : Build Release and install to /Applications"
	@echo "  make logs            : Stream live application logs"
	@echo "  make clean           : Clean build artifacts and cache"
