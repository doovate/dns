#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env

ok=0
fail=0

check(){
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[OK] $name"; ((ok++))
  else
    echo "[FAIL] $name"; ((fail++))
  fi
}

check "pdns service" systemctl is-active --quiet pdns
check "pdns-recursor service" systemctl is-active --quiet pdns-recursor
check "powerdns-admin service" systemctl is-active --quiet powerdns-admin

check "pdns api" bash -c "curl -fsS -H 'X-API-Key: ${PDNS_API_KEY}' http://127.0.0.1:${PDNS_API_PORT}/api/v1/servers >/dev/null"
check "dns internal ${DNS_ZONE}" bash -c "[[ \"$(dig +short @${DNS_SERVER_IP} dns.${DNS_ZONE})\" == \"${DNS_SERVER_IP}\" ]]"

echo "OK=$ok FAIL=$fail"
if (( fail > 0 )); then exit 1; fi
