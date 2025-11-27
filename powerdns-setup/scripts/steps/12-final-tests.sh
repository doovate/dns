#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 12: Pruebas finales"

# DNS internal resolution test
run_cmd bash scripts/test-dns.sh "$DNS_ZONE" "$DNS_SERVER_IP" || true

# Web UI access
run_cmd curl -sk https://$DNS_SERVER_IP:$WEBUI_PORT/ -o /dev/null -w "%{http_code}\n" || true

# API test (PDNS auth webserver)
run_cmd curl -s http://127.0.0.1:8081/api/v1/servers -H "X-API-Key: ${PDNS_API_KEY:-changeme}" || true

log_success "Pruebas finales ejecutadas"
