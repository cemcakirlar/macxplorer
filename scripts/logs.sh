#!/usr/bin/env bash
set -euo pipefail

BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}📋 Streaming live Macxplorer logs (Press Ctrl+C to exit)...${NC}"
log stream --predicate 'subsystem == "com.cakirlarc.macxplorer"' --level info --style compact
