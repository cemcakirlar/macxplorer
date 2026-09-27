#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

PROCESS_NAME="Macxplorer"

# Find running PIDs
PIDS=$(pgrep -x "$PROCESS_NAME" 2>/dev/null || true)

if [ -z "$PIDS" ]; then
    echo -e "${BLUE}ℹ️  No running $PROCESS_NAME process found.${NC}"
    exit 0
fi

echo -e "${YELLOW}🛑 Stopping $PROCESS_NAME (PID: $PIDS)...${NC}"

# Graceful termination (SIGTERM)
kill $PIDS 2>/dev/null || true

# Wait up to 3 seconds for exit
WAIT_SECONDS=3
TERMINATED=false

for ((i=0; i<WAIT_SECONDS*10; i++)); do
    if ! pgrep -x "$PROCESS_NAME" > /dev/null 2>&1; then
        TERMINATED=true
        break
    fi
    sleep 0.1
done

# Force kill if not exited (SIGKILL)
if [ "$TERMINATED" = false ]; then
    echo -e "${YELLOW}⚠️  Application did not exit cleanly; forcing shutdown (SIGKILL)...${NC}"
    killall -9 "$PROCESS_NAME" 2>/dev/null || true
    sleep 0.2
fi

if ! pgrep -x "$PROCESS_NAME" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ $PROCESS_NAME stopped successfully.${NC}"
else
    echo -e "${RED}❌ Failed to stop $PROCESS_NAME!${NC}"
    exit 1
fi
