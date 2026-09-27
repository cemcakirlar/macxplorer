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
DO_CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --release|--Release|-r)
            CONFIG="Release"
            ;;
        --debug|--Debug|-d)
            CONFIG="Debug"
            ;;
        --clean|-c)
            DO_CLEAN=true
            ;;
        --help|-h)
            echo "Usage: ./scripts/build.sh [--debug | --release] [--clean]"
            echo "  --debug, -d   : Compile in Debug configuration (Default)"
            echo "  --release, -r : Compile in Release configuration"
            echo "  --clean, -c   : Clean build cache before compiling"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown parameter: $arg${NC}"
            exit 1
            ;;
    esac
done

DERIVED_DATA_DIR="$PROJECT_ROOT/.build/DerivedData"

if [ "$DO_CLEAN" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build cache...${NC}"
    rm -rf "$DERIVED_DATA_DIR"
    if [ $# -eq 1 ]; then
        echo -e "${GREEN}✅ Build cache cleaned.${NC}"
        exit 0
    fi
fi

echo -e "${BLUE}${BOLD}🔨 Building MacXplorer... [Config: $CONFIG]${NC}"
START_TIME=$(date +%s)

xcodebuild \
    -project Macxplorer.xcodeproj \
    -scheme Macxplorer \
    -destination 'platform=macOS' \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1 | grep -v -E "IDEDownloadableMetalToolchainCoordinator|IDESimulatorRuntimeVersionCoordinator|Operation not permitted|Supported platforms for the buildables|matching destinations" || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIG/Macxplorer.app"

if [ -d "$APP_PATH" ]; then
    # Local ad-hoc codesigning
    codesign --force --deep --sign - "$APP_PATH" > /dev/null 2>&1 || true

    echo -e "${GREEN}✅ Build completed successfully! (${DURATION}s)${NC}"
    echo -e "   📦 Location: ${BOLD}$APP_PATH${NC}"
else
    echo -e "${RED}❌ Build finished but $APP_PATH was not found!${NC}"
    exit 1
fi
