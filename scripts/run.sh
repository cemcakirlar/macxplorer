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

CONFIG="Debug"
DO_BUILD=true
FOREGROUND=false

for arg in "$@"; do
    case "$arg" in
        --release|-r)
            CONFIG="Release"
            ;;
        --debug|-d)
            CONFIG="Debug"
            ;;
        --no-build|-n)
            DO_BUILD=false
            ;;
        --foreground|-f)
            FOREGROUND=true
            ;;
        --help|-h)
            echo "Usage: ./scripts/run.sh [OPTIONS]"
            echo "  --debug, -d       : Build and launch Debug configuration (Default)"
            echo "  --release, -r     : Build and launch Release configuration"
            echo "  --foreground, -f  : Run in terminal foreground (shows live stdout/stderr)"
            echo "  --no-build, -n    : Run existing binary without rebuilding"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown parameter: $arg${NC}"
            exit 1
            ;;
    esac
done

# 1. Terminate any previous instance
"$SCRIPT_DIR/stop.sh"

# 2. Build if requested
if [ "$DO_BUILD" = true ]; then
    if [ "$CONFIG" = "Release" ]; then
        "$SCRIPT_DIR/build.sh" --release
    else
        "$SCRIPT_DIR/build.sh" --debug
    fi
fi

APP_PATH="$PROJECT_ROOT/.build/DerivedData/Build/Products/$CONFIG/Macxplorer.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/Macxplorer"

if [ ! -d "$APP_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}❌ Application bundle not found: $APP_PATH${NC}"
    echo "Please run './scripts/build.sh' first."
    exit 1
fi

if [ "$FOREGROUND" = true ]; then
    echo -e "${BLUE}🚀 Launching MacXplorer in foreground (Press Ctrl+C to terminate)...${NC}"
    "$BINARY_PATH"
else
    echo -e "${BLUE}🚀 Launching MacXplorer...${NC}"
    open "$APP_PATH"

    sleep 0.8
    NEW_PID=$(pgrep -x "Macxplorer" 2>/dev/null || true)
    if [ -n "$NEW_PID" ]; then
        echo -e "${GREEN}✅ MacXplorer is up and running! (PID: $NEW_PID)${NC}"
    else
        echo -e "${YELLOW}⚠️  Application launched; check for the MacXplorer window.${NC}"
    fi
fi
