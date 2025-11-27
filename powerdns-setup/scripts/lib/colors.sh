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

box_top() { local title="$1"; echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗\n║  ${title}$(printf '%*s' $((56 - ${#title})) '' )║\n╚════════════════════════════════════════════════════════════╝${NORMAL}"; }
check_ok(){ echo -e "${GREEN}✓${NORMAL}"; }
check_fail(){ echo -e "${RED}✗${NORMAL}"; }
