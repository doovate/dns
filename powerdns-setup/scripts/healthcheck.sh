#!/usr/bin/env bash
set -euo pipefail

GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; NC='\e[0m'

check_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    echo -e "${GREEN}[OK]${NC} $svc is active"
  else
    echo -e "${RED}[DOWN]${NC} $svc is not active"
    systemctl status "$svc" --no-pager -l || true
  fi
}

echo -e "\n== PowerDNS Stack Healthcheck ==\n"
check_service pdns
check_service pdns-recursor
check_service powerdns-admin
check_service nginx

echo -e "\nListening ports (53, 5300, 8081, 9190, WEBUI):\n"
ss -ltnup | awk 'NR==1 || /(:53 |:5300 |:8081 |:9190 )/' || true

echo -e "\nUFW status:\n"
ufw status verbose || true

echo -e "\nPDNS version:\n"
pdns_server --version 2>/dev/null || true
recursor --version 2>/dev/null || true
