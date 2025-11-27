#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 4: Instalación PowerDNS Authoritative"

# Install package and backend for DB
run_cmd apt-get install -y pdns-server pdns-backend-pgsql pdns-backend-mysql || true

# Configure pdns.conf from template
mkdir -p /etc/powerdns 2>/dev/null || true
if [ -f configs/pdns.conf.template ]; then
  log_info "Generando /etc/powerdns/pdns.conf"
  DB_DSN=""
  case "$DB_TYPE" in
    postgresql)
      DB_DSN="pgsql:host=${DB_HOST:-127.0.0.1};dbname=$DB_NAME;user=$DB_USER;password=$DB_PASSWORD"
      ;;
    mysql|mariadb)
      DB_DSN="mysql:host=${DB_HOST:-127.0.0.1};dbname=$DB_NAME;user=$DB_USER;password=$DB_PASSWORD"
      ;;
  esac
  export PDNS_AUTH_PORT DB_DSN
  run_cmd envsubst < configs/pdns.conf.template > /etc/powerdns/pdns.conf
  run_cmd chmod 640 /etc/powerdns/pdns.conf
fi

# Enable and restart service
run_cmd systemctl enable pdns || true
run_cmd systemctl restart pdns || true

log_success "PowerDNS Authoritative instalado y configurado"
