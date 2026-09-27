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

DO_CLEAN=false
TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean|-c)
            DO_CLEAN=true
            shift
            ;;
        --version|-v)
            TARGET_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./scripts/package.sh [OPTIONS]"
            echo "  --version, -v <version> : Specify version tag (Default: read from project.pbxproj)"
            echo "  --clean, -c             : Clean build cache before packaging"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown parameter: $1${NC}"
            exit 1
            ;;
    esac
done

# Detect version
if [ -z "$TARGET_VERSION" ]; then
    TARGET_VERSION=$(grep -m1 "MARKETING_VERSION" Macxplorer.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/' | tr -d ' "')
fi

BUILD_NUM=$(grep -m1 "CURRENT_PROJECT_VERSION" Macxplorer.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/' | tr -d ' "')

echo -e "${BLUE}${BOLD}📦 Packaging Macxplorer...${NC}"
echo -e "   Version : ${BOLD}v${TARGET_VERSION} (Build ${BUILD_NUM})${NC}"

# 1. Run Release build
BUILD_ARGS=("--release")
if [ "$DO_CLEAN" = true ]; then
    BUILD_ARGS+=("--clean")
fi

"$SCRIPT_DIR/build.sh" "${BUILD_ARGS[@]}"

SOURCE_APP="$PROJECT_ROOT/.build/DerivedData/Build/Products/Release/Macxplorer.app"
if [ ! -d "$SOURCE_APP" ]; then
    echo -e "${RED}❌ Build output not found: $SOURCE_APP${NC}"
    exit 1
fi

# 2. Prepare staging and distribution directories
DIST_DIR="$PROJECT_ROOT/dist"
STAGING_DIR="$PROJECT_ROOT/.build/staging"
rm -rf "$STAGING_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

APP_NAME="Macxplorer.app"
STAGED_APP="$STAGING_DIR/$APP_NAME"

echo -e "${BLUE}📋 Preparing application bundle...${NC}"
cp -R "$SOURCE_APP" "$STAGED_APP"

# Ad-hoc codesign & quarantine clearance
echo -e "${BLUE}🔐 Signing and validating permissions...${NC}"
codesign --force --deep --sign - "$STAGED_APP" > /dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$STAGED_APP" 2>/dev/null || true

# 3. Create .zip archive using macOS ditto tool
ZIP_NAME="Macxplorer-v${TARGET_VERSION}-macOS.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
SHA_PATH="${ZIP_PATH}.sha256"

echo -e "${BLUE}🗜️  Archiving macOS bundle via ditto...${NC}"
rm -f "$ZIP_PATH" "$SHA_PATH"

# ditto preserves permissions, symlinks, and resource forks
(cd "$STAGING_DIR" && ditto -c -k --keepParent "$APP_NAME" "$ZIP_PATH")

# 4. Generate SHA-256 Checksum
echo -e "${BLUE}🔑 Calculating SHA-256 checksum...${NC}"
(cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256")

# Package size
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
SHA_CHECKSUM=$(cut -d ' ' -f 1 "$SHA_PATH")

echo -e "${GREEN}${BOLD}🎉 Distribution package generated successfully!${NC}"
echo -e "   📦 Archive  : ${BOLD}$ZIP_PATH${NC} (${ZIP_SIZE})"
echo -e "   📄 SHA-256  : ${BOLD}$SHA_CHECKSUM${NC}"
echo -e "   📁 Directory: ${DIST_DIR}"
