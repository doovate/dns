#!/bin/bash
set -euo pipefail
source config.env

ok=true

check_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    echo "[OK] $svc activo"
  else
    echo "[FAIL] $svc no activo"; ok=false
  fi
}

check_port() {
  local port="$1"; local name="$2"
  if ss -lnt | awk '{print $4}' | grep -q ":$port$"; then
    echo "[OK] Puerto $port ($name) en escucha"
  else
    echo "[FAIL] Puerto $port ($name) no está en escucha"; ok=false
  fi
}

check_service pdns || true
check_service pdns-recursor || true
check_service powerdns-admin || true
check_service nginx || true

check_port "$PDNS_RECURSOR_PORT" "Recursor" || true
check_port "$PDNS_AUTH_PORT" "Authoritative" || true
check_port "$WEBUI_PORT" "Nginx WebUI" || true

scripts/test-dns.sh "$DNS_ZONE" "$DNS_SERVER_IP" || true

$ok || exit 1
