#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

main(){
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y dnsutils curl"

  # Test servicios
  systemctl is-active --quiet pdns && echo "✓ PowerDNS Auth OK" || echo "✗ PowerDNS Auth FAILED"
  systemctl is-active --quiet pdns-recursor && echo "✓ PowerDNS Recursor OK" || echo "✗ PowerDNS Recursor FAILED"
  systemctl is-active --quiet powerdns-admin && echo "✓ PowerDNS-Admin OK" || echo "✗ PowerDNS-Admin FAILED"
  systemctl is-active --quiet nginx && echo "✓ Nginx OK" || echo "✗ Nginx FAILED"

  # Test resolución interna
  if dig @"${DNS_SERVER_IP}" "dv-vpn.${DNS_ZONE}" +short | grep -q "192.168.24.20"; then
    echo "✓ DNS Interno OK"
  else
    echo "✗ DNS Interno FAILED"
  fi

  # Test resolución externa
  if dig @"${DNS_SERVER_IP}" google.com +short | grep -q "."; then
    echo "✓ DNS Externo OK"
  else
    echo "✗ DNS Externo FAILED"
  fi

  # Test Web UI
  if curl -k -s -o /dev/null -w "%{http_code}" "https://${DNS_SERVER_IP}:${NGINX_HTTPS_PORT}" | grep -q "200\|302"; then
    echo "✓ Web UI OK"
  else
    echo "✗ Web UI FAILED"
  fi

  progress_set "$STEP_KEY" "completed"
}

main "$@"
