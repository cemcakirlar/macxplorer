#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Defaults
DRY_RUN=false
NO_PUSH=false
SKIP_BUILD=false
ALLOW_DIRTY=false
BUMP_TYPE="patch"

print_help() {
    cat <<EOF
MacXplorer - Release Cycle & Version Manager

Usage:
  ./scripts/release.sh [patch | minor | major | <version>] [OPTIONS]

Default release = patch. Use minor/major only when explicitly requested.

Options:
  patch                  : Bump patch version (e.g. 1.0.3 -> 1.0.4) [DEFAULT]
  minor                  : Bump minor version (e.g. 1.0.0 -> 1.1.0) — not the default
  major                  : Bump major version (e.g. 1.0.0 -> 2.0.0) — not the default
  <X.Y.Z>                : Specify exact SemVer version (e.g. 1.2.0)
  --dry-run              : Simulate all steps without making permanent changes
  --no-push              : Commit and tag locally, but do not push to remote or GitHub
  --skip-build           : Skip build and packaging step
  --allow-dirty          : Allow running with uncommitted git working tree
  --help, -h             : Show this help message

Examples:
  ./scripts/release.sh patch
  ./scripts/release.sh minor --dry-run
  ./scripts/release.sh 1.2.0 --no-push
EOF
}

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        patch|minor|major)
            BUMP_TYPE="$arg"
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --no-push)
            NO_PUSH=true
            ;;
        --skip-build)
            SKIP_BUILD=true
            ;;
        --allow-dirty)
            ALLOW_DIRTY=true
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
                BUMP_TYPE="$arg"
            else
                echo -e "${RED}Unknown or invalid parameter: $arg${NC}"
                print_help
                exit 1
            fi
            ;;
    esac
done

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}🚀 MacXplorer — RELEASE CYCLE ORCHESTRATOR${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}⚠️  DRY-RUN MODE ACTIVE: No permanent changes will be applied.${NC}\n"
fi

# ==============================================================================
# STEP 1: PREFLIGHT & ENVIRONMENT CHECKS
# ==============================================================================
echo -e "${BLUE}${BOLD}[1/7] Environment and Preflight Checks...${NC}"

# CLI tools check
for tool in git xcodebuild ditto shasum; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo -e "${RED}❌ Required CLI tool not found: $tool${NC}"
        exit 1
    fi
done

if ! command -v gh > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  'gh' (GitHub CLI) not found. Releases cannot be published to GitHub.${NC}"
    if [ "$NO_PUSH" = false ] && [ "$DRY_RUN" = false ]; then
        echo -e "${RED}Please install with 'brew install gh' or run with '--no-push'.${NC}"
        exit 1
    fi
fi

# Git working tree check
if [ "$ALLOW_DIRTY" = false ] && [ "$DRY_RUN" = false ]; then
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}❌ Git working tree has uncommitted changes!${NC}"
        echo -e "   Please commit or stash your changes before releasing."
        echo -e "   (Use '--allow-dirty' or '--dry-run' for testing)"
        exit 1
    fi
fi

# Active branch check
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Current branch is '${CURRENT_BRANCH}' (Recommended: 'main').${NC}"
fi

echo -e "${GREEN}✅ Environment checks passed.${NC}"

# ==============================================================================
# STEP 2: VERSION CALCULATION (SEMVER)
# ==============================================================================
echo -e "\n${BLUE}${BOLD}[2/7] Semantic Versioning (SemVer)...${NC}"

PBXPROJ_FILE="Macxplorer.xcodeproj/project.pbxproj"
CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION" "$PBXPROJ_FILE" | sed -E 's/.*= ([^;]+);/\1/' | tr -d ' "')
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" "$PBXPROJ_FILE" | sed -E 's/.*= ([^;]+);/\1/' | tr -d ' "')

if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.0.0"
fi
if [ -z "$CURRENT_BUILD" ]; then
    CURRENT_BUILD="1"
fi

bump_version() {
    local cur="$1"
    local mode="$2"
    local major minor patch
    IFS="." read -r major minor patch <<< "$cur"
    patch=${patch:-0}
    minor=${minor:-0}
    major=${major:-0}

    case "$mode" in
        patch)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
        minor)
            echo "${major}.$((minor + 1)).0"
            ;;
        major)
            echo "$((major + 1)).0.0"
            ;;
        *)
            echo "$mode"
            ;;
    esac
}

NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")
NEW_BUILD=$((CURRENT_BUILD + 1))

echo -e "   Current Version : ${BOLD}v${CURRENT_VERSION} (Build ${CURRENT_BUILD})${NC}"
echo -e "   New Version     : ${GREEN}${BOLD}v${NEW_VERSION} (Build ${NEW_BUILD})${NC}"

# ==============================================================================
# STEP 3: CONVENTIONAL COMMITS & CHANGELOG GENERATION
# ==============================================================================
echo -e "\n${BLUE}${BOLD}[3/7] Parsing Conventional Commits & Generating Changelog...${NC}"

PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# If re-releasing the current tag, find the tag before it
if [ "$PREV_TAG" = "v${NEW_VERSION}" ]; then
    PREV_TAG=$(git describe --tags --abbrev=0 "v${NEW_VERSION}^" 2>/dev/null || echo "")
fi

LOG_RANGE="HEAD"
if [ -n "$PREV_TAG" ]; then
    LOG_RANGE="${PREV_TAG}..HEAD"
    echo -e "   Previous Tag    : ${BOLD}${PREV_TAG}${NC}"
else
    echo -e "   Previous Tag    : ${YELLOW}(Initial release - parsing full git history)${NC}"
fi

FEATS=()
FIXES=()
PERFS=()
CHORES=()
OTHERS=()

while IFS='|' read -r subject hash || [ -n "$subject" ]; do
    [ -z "$subject" ] && continue
    case "$subject" in
        chore\(release\)*|"chore: release"*)
            # Skip automated release commits
            continue
            ;;
        feat*|Feat*)
            FEATS+=("- ${subject} (\`${hash}\`)")
            ;;
        fix*|Fix*)
            FIXES+=("- ${subject} (\`${hash}\`)")
            ;;
        perf*|refactor*|Perf*|Refactor*)
            PERFS+=("- ${subject} (\`${hash}\`)")
            ;;
        chore*|docs*|build*|ci*|test*|style*|Chore*|Docs*)
            CHORES+=("- ${subject} (\`${hash}\`)")
            ;;
        *)
            OTHERS+=("- ${subject} (\`${hash}\`)")
            ;;
    esac
done < <(git log --pretty=format:"%s|%h" "$LOG_RANGE" 2>/dev/null || true)

TODAY=$(date +%Y-%m-%d)
RELEASE_NOTES="## [v${NEW_VERSION}] - ${TODAY}\n\n"

if [ ${#FEATS[@]} -gt 0 ]; then
    RELEASE_NOTES+="### Features\n"
    for item in "${FEATS[@]}"; do
        RELEASE_NOTES+="${item}\n"
    done
    RELEASE_NOTES+="\n"
fi

if [ ${#FIXES[@]} -gt 0 ]; then
    RELEASE_NOTES+="### Bug Fixes\n"
    for item in "${FIXES[@]}"; do
        RELEASE_NOTES+="${item}\n"
    done
    RELEASE_NOTES+="\n"
fi

if [ ${#PERFS[@]} -gt 0 ]; then
    RELEASE_NOTES+="### Performance & Refactoring\n"
    for item in "${PERFS[@]}"; do
        RELEASE_NOTES+="${item}\n"
    done
    RELEASE_NOTES+="\n"
fi

if [ ${#CHORES[@]} -gt 0 ]; then
    RELEASE_NOTES+="### Maintenance & Tooling\n"
    for item in "${CHORES[@]}"; do
        RELEASE_NOTES+="${item}\n"
    done
    RELEASE_NOTES+="\n"
fi

if [ ${#OTHERS[@]} -gt 0 ]; then
    RELEASE_NOTES+="### Other Changes\n"
    for item in "${OTHERS[@]}"; do
        RELEASE_NOTES+="${item}\n"
    done
    RELEASE_NOTES+="\n"
fi

# Append macOS Gatekeeper guidance for end users
RELEASE_NOTES+="---\n\n"
RELEASE_NOTES+="### macOS Installation & Gatekeeper Note\n"
RELEASE_NOTES+="Because this open-source build is distributed outside the Mac App Store without a paid Apple Developer ID, macOS Gatekeeper may show a warning (*\"Apple could not verify...\"*) on first launch.\n\n"
RELEASE_NOTES+="**To open the app, run this single command in Terminal:**\n"
RELEASE_NOTES+="\`\`\`bash\nxattr -cr \"/Applications/Macxplorer.app\"\n\`\`\`\n"
RELEASE_NOTES+="*Alternatively, open **System Settings ➔ Privacy & Security** and click **Open Anyway**.* \n\n"

if [ ${#FEATS[@]} -eq 0 ] && [ ${#FIXES[@]} -eq 0 ] && [ ${#PERFS[@]} -eq 0 ] && [ ${#CHORES[@]} -eq 0 ] && [ ${#OTHERS[@]} -eq 0 ]; then
    RELEASE_NOTES+="### Changes\n- Release v${NEW_VERSION} of MacXplorer.\n\n"
fi

BUILD_DIR="$PROJECT_ROOT/.build"
mkdir -p "$BUILD_DIR"
RELEASE_NOTES_FILE="$BUILD_DIR/release-notes-v${NEW_VERSION}.md"
printf "%b" "$RELEASE_NOTES" > "$RELEASE_NOTES_FILE"

echo -e "   📄 Release Notes Prepared (${RELEASE_NOTES_FILE})"

CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
HEADER="# Changelog\n\nAll notable changes to MacXplorer will be documented in this file.\nThe format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n"

if [ "$DRY_RUN" = false ]; then
    if [ ! -f "$CHANGELOG_FILE" ]; then
        printf "%b\n%b\n" "$HEADER" "$RELEASE_NOTES" > "$CHANGELOG_FILE"
    elif ! grep -q "## \[v${NEW_VERSION}\]" "$CHANGELOG_FILE"; then
        BODY=$(awk 'NR>4' "$CHANGELOG_FILE" 2>/dev/null || cat "$CHANGELOG_FILE")
        printf "%b\n%b\n%s\n" "$HEADER" "$RELEASE_NOTES" "$BODY" > "$CHANGELOG_FILE"
    fi
    echo -e "${GREEN}✅ CHANGELOG.md updated.${NC}"
else
    echo -e "${YELLOW}ℹ️  DRY-RUN: CHANGELOG.md write skipped.${NC}"
fi

# ==============================================================================
# STEP 4: UPDATE PROJECT METADATA
# ==============================================================================
echo -e "\n${BLUE}${BOLD}[4/7] Updating Project Version Metadata...${NC}"

if [ "$DRY_RUN" = false ]; then
    sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${NEW_VERSION};/g" "$PBXPROJ_FILE"
    sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" "$PBXPROJ_FILE"
    echo -e "${GREEN}✅ $PBXPROJ_FILE updated (MARKETING_VERSION: $NEW_VERSION, CURRENT_PROJECT_VERSION: $NEW_BUILD).${NC}"
else
    echo -e "${YELLOW}ℹ️  DRY-RUN: $PBXPROJ_FILE update skipped.${NC}"
fi

# ==============================================================================
# STEP 5: COMPILE RELEASE AND PACKAGE ARTIFACTS
# ==============================================================================
echo -e "\n${BLUE}${BOLD}[5/7] Release Build and Packaging Artifacts...${NC}"

DIST_ZIP="$PROJECT_ROOT/dist/Macxplorer-v${NEW_VERSION}-macOS.zip"
DIST_SHA="$PROJECT_ROOT/dist/Macxplorer-v${NEW_VERSION}-macOS.zip.sha256"

if [ "$SKIP_BUILD" = false ]; then
    if [ "$DRY_RUN" = false ]; then
        "$SCRIPT_DIR/package.sh" --version "$NEW_VERSION"
    else
        echo -e "${YELLOW}ℹ️  DRY-RUN: Packaging step simulated (skipped).${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  --skip-build: Build and packaging skipped.${NC}"
fi

# ==============================================================================
# STEP 6: GIT COMMIT AND ANNOTATED TAG
# ==============================================================================
echo -e "\n${BLUE}${BOLD}[6/7] Creating Git Commit and Tag...${NC}"

TAG_NAME="v${NEW_VERSION}"
COMMIT_MSG="chore(release): ${TAG_NAME}"

if [ "$DRY_RUN" = false ]; then
    git add "$PBXPROJ_FILE" "$CHANGELOG_FILE"
    git commit -m "$COMMIT_MSG" || true
    echo -e "   ✅ Commit created: ${BOLD}${COMMIT_MSG}${NC}"

    if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Tag ${TAG_NAME} already exists, overwriting...${NC}"
        git tag -d "$TAG_NAME" > /dev/null 2>&1 || true
    fi
    git tag -a "$TAG_NAME" -m "Release ${TAG_NAME}"
    echo -e "${GREEN}✅ Git tag created: ${BOLD}${TAG_NAME}${NC}"
else
    echo -e "${YELLOW}ℹ️  DRY-RUN: 'git commit -m \"${COMMIT_MSG}\"' and 'git tag -a ${TAG_NAME}' skipped.${NC}"
fi

# ==============================================================================
# STEP 7: PUSH AND GITHUB RELEASE
# ==============================================================================
echo -e "\n${BLUE}${BOLD}[7/7] Git Push and GitHub Release...${NC}"

if [ "$NO_PUSH" = false ] && [ "$DRY_RUN" = false ]; then
    echo -e "${BLUE}📤 Pushing git branch and tags to origin...${NC}"
    git push origin "$CURRENT_BRANCH"
    git push origin "$TAG_NAME" --force
    echo -e "${GREEN}✅ Git push completed.${NC}"

    if command -v gh > /dev/null 2>&1; then
        echo -e "${BLUE}🚀 Publishing GitHub Release via gh CLI...${NC}"

        ASSETS=()
        if [ -f "$DIST_ZIP" ]; then
            ASSETS+=("$DIST_ZIP")
        fi
        if [ -f "$DIST_SHA" ]; then
            ASSETS+=("$DIST_SHA")
        fi

        if gh release view "$TAG_NAME" > /dev/null 2>&1; then
            echo -e "${YELLOW}ℹ️  Updating existing GitHub release...${NC}"
            gh release edit "$TAG_NAME" --title "MacXplorer ${TAG_NAME}" --notes-file "$RELEASE_NOTES_FILE"
            if [ ${#ASSETS[@]} -gt 0 ]; then
                gh release upload "$TAG_NAME" "${ASSETS[@]}" --clobber
            fi
        else
            gh release create "$TAG_NAME" \
                "${ASSETS[@]}" \
                --title "MacXplorer ${TAG_NAME}" \
                --notes-file "$RELEASE_NOTES_FILE"
        fi

        echo -e "${GREEN}✅ GitHub Release created successfully!${NC}"
        gh release view "$TAG_NAME" --web 2>/dev/null || true
    fi
else
    echo -e "${YELLOW}ℹ️  GitHub release skipped due to --no-push or --dry-run.${NC}"
    echo -e "   To push manually:"
    echo -e "   git push origin $CURRENT_BRANCH && git push origin $TAG_NAME"
    if [ -f "$DIST_ZIP" ]; then
        echo -e "   gh release create $TAG_NAME \"$DIST_ZIP\" \"$DIST_SHA\" --title \"MacXplorer $TAG_NAME\" --notes-file \"$RELEASE_NOTES_FILE\""
    fi
fi

echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}🎉 RELEASE CYCLE COMPLETED SUCCESSFULLY: ${TAG_NAME}${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   📦 Distribution Archive : ${DIST_ZIP:-'Not built'}"
echo -e "   🏷️  Git Tag              : ${TAG_NAME}"
echo -e "   📄 Changelog            : ${CHANGELOG_FILE}"
echo ""
