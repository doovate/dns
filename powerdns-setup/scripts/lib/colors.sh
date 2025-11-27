#!/bin/bash
# Simple ANSI color helpers
if [ -t 1 ]; then
  NC='\033[0m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
else
  NC=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''
fi

color_info() { echo -e "${CYAN}$*${NC}"; }
color_warn() { echo -e "${YELLOW}$*${NC}"; }
color_error() { echo -e "${RED}$*${NC}"; }
color_success() { echo -e "${GREEN}$*${NC}"; }
color_title() { echo -e "${BOLD}$*${NC}"; }
