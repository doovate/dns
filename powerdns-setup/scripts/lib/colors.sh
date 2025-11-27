#!/usr/bin/env bash
# Colores y formato para salida en terminal

if [ -t 1 ]; then
  NORMAL='\033[0m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
else
  NORMAL=''
  BOLD=''
  DIM=''
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
fi

box_top() {
  local title="$1"
  local box_width=60
  # We print a 60-char wide box; inner content has 58 chars (borders use 2)
  local inner_width=$((box_width - 2))
  # We prefix with two spaces inside before title to match original aesthetic "║  "; adjust padding accordingly
  local prefix="  "
  local content_len=$(( ${#prefix} + ${#title} ))
  local pad=$(( inner_width - content_len ))
  if [ $pad -lt 0 ]; then pad=0; fi
  # Build padding string of spaces with length pad
  local padding
  padding=$(printf '%*s' "$pad" '') || padding=""
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗\n║${prefix}${title}${padding}║\n╚════════════════════════════════════════════════════════════╝${NORMAL}"
}
check_ok(){ echo -e "${GREEN}✓${NORMAL}"; }
check_fail(){ echo -e "${RED}✗${NORMAL}"; }
