#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: ./scripts/test.sh"
            echo "  Runs the unit tests in Debug. The full xcodebuild output goes to .build/test.log"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown parameter: $arg${NC}"
            exit 1
            ;;
    esac
done

DERIVED_DATA_DIR="$PROJECT_ROOT/.build/DerivedData"
LOG_PATH="$PROJECT_ROOT/.build/test.log"
mkdir -p "$PROJECT_ROOT/.build"

echo -e "${BLUE}${BOLD}🧪 Testing MacXplorer...${NC}"
START_TIME=$(date +%s)

# grep exits 1 when it filters every line, so only xcodebuild's status decides the result.
set +e
xcodebuild \
    -project Macxplorer.xcodeproj \
    -scheme Macxplorer \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    test \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$LOG_PATH" | grep -E "error:|: error -|with [1-9][0-9]* failures|\*\* TEST" | grep -v "com.apple.linkd"
TEST_STATUS=${PIPESTATUS[0]}
set -e

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
SUMMARY=$(grep -E "^[[:space:]]*Executed [0-9]+ tests" "$LOG_PATH" | tail -1 | sed -E 's/^[[:space:]]+//' || true)

if [ "$TEST_STATUS" -ne 0 ]; then
    echo -e "${RED}❌ Tests failed (xcodebuild exit $TEST_STATUS, ${DURATION}s)${NC}"
    [ -n "$SUMMARY" ] && echo "   $SUMMARY"
    echo -e "   📄 Full log: ${BOLD}$LOG_PATH${NC}"
    exit "$TEST_STATUS"
fi

echo -e "${GREEN}✅ Tests passed! (${DURATION}s)${NC}"
[ -n "$SUMMARY" ] && echo "   $SUMMARY"
exit 0
