#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 11: Inicio de servicios"

SERVICES=(
  postgresql
  mariadb
  pdns
  pdns-recursor
  powerdns-admin
  nginx
)

for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}\.service"; then
    run_cmd systemctl enable "$svc"
    run_cmd systemctl restart "$svc" || true
    run_cmd systemctl status --no-pager "$svc" || true
  fi
done

log_success "Servicios iniciados"
