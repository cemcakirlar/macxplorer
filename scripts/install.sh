#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIG="Release"
DEST_DIR="/Applications"
AUTO_LAUNCH=true

for arg in "$@"; do
    case "$arg" in
        --release|-r)
            CONFIG="Release"
            ;;
        --debug|-d)
            CONFIG="Debug"
            ;;
        --user|-u)
            DEST_DIR="$HOME/Applications"
            ;;
        --no-launch)
            AUTO_LAUNCH=false
            ;;
        --help|-h)
            echo "Usage: ./scripts/install.sh [OPTIONS]"
            echo "  --release, -r  : Compile in Release (Production) mode and install (Default)"
            echo "  --debug, -d    : Compile in Debug mode and install"
            echo "  --user, -u     : Install to ~/Applications instead of /Applications"
            echo "  --no-launch    : Do not automatically launch after installation"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown parameter: $arg${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}${BOLD}📦 MacXplorer Installation${NC}"
echo -e "   Configuration : ${BOLD}$CONFIG${NC}"
echo -e "   Target Path   : ${BOLD}$DEST_DIR${NC}"

# 1. Terminate old running instance
"$SCRIPT_DIR/stop.sh"

# 2. Build
if [ "$CONFIG" = "Release" ]; then
    "$SCRIPT_DIR/build.sh" --release
else
    "$SCRIPT_DIR/build.sh" --debug
fi

SOURCE_APP="$PROJECT_ROOT/.build/DerivedData/Build/Products/$CONFIG/Macxplorer.app"
TARGET_APP="$DEST_DIR/Macxplorer.app"

# Ensure target directory exists
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p "$DEST_DIR"
fi

# Check permissions for /Applications
if [ ! -w "$DEST_DIR" ]; then
    echo -e "${YELLOW}⚠️  No write permission for $DEST_DIR. Falling back to user directory ($HOME/Applications)...${NC}"
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
    TARGET_APP="$DEST_DIR/Macxplorer.app"
fi

# Remove older version if present
if [ -d "$TARGET_APP" ]; then
    echo -e "${YELLOW}🗑️  Removing previous installation: $TARGET_APP${NC}"
    rm -rf "$TARGET_APP"
fi

echo -e "${BLUE}📋 Copying application bundle...${NC}"
cp -R "$SOURCE_APP" "$TARGET_APP"
touch "$TARGET_APP"

# Ad-hoc signing & quarantine clearance
echo -e "${BLUE}🔐 Signing and validating permissions...${NC}"
codesign --force --deep --sign - "$TARGET_APP" > /dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

# Register with macOS LaunchServices (Spotlight & Launchpad)
if [ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$TARGET_APP" > /dev/null 2>&1 || true
fi

echo -e "${GREEN}🎉 INSTALLATION COMPLETED SUCCESSFULLY!${NC}"
echo -e "   Path: ${BOLD}$TARGET_APP${NC}"
echo -e "   • Launch anytime via Spotlight (Cmd + Space): '${BOLD}MacXplorer${NC}'"

if [ "$AUTO_LAUNCH" = true ]; then
    echo -e "\n${BLUE}🚀 Launching application...${NC}"
    open "$TARGET_APP"
    sleep 0.8
    NEW_PID=$(pgrep -x "Macxplorer" 2>/dev/null || true)
    if [ -n "$NEW_PID" ]; then
        echo -e "${GREEN}✅ MacXplorer is running. (PID: $NEW_PID)${NC}"
    fi
fi
