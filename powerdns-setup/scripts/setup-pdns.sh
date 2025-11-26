#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env
require_root

info "Aplicando configuración de PowerDNS"

# Ensure directories
install -d -o root -g root /etc/powerdns || true

# Render configs
render_template "$ROOT_DIR/configs/recursor.conf.template" /etc/powerdns/recursor.conf
render_template "$ROOT_DIR/configs/pdns.conf.template" /etc/powerdns/pdns.conf

# Enable services
systemctl enable pdns-recursor || true
systemctl enable pdns || true

# Initialize database schema for pdns (PostgreSQL)
if [[ "$DB_ENGINE" == "POSTGRES" ]]; then
  SCHEMA_FILE="/usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql"
  if [[ -f "$SCHEMA_FILE" ]]; then
    info "Aplicando esquema de PowerDNS si es necesario"
    sudo -u postgres psql -d "${PDNS_DB_NAME}" -c "\dt" | grep -q domains || \
      sudo -u postgres psql -d "${PDNS_DB_NAME}" -f "$SCHEMA_FILE"
  else
    warn "No se encontró el esquema en $SCHEMA_FILE"
  fi
else
  error "Solo PostgreSQL soportado en esta versión"; exit 1
fi

# Start services
systemctl restart pdns || true
systemctl restart pdns-recursor || true
sleep 2

# Create internal zone and records idempotently
if ! pdnsutil list-all-zones | grep -q "^${DNS_ZONE}$"; then
  info "Creando zona ${DNS_ZONE}"
  pdnsutil create-zone "${DNS_ZONE}" "dns.${DNS_ZONE}" || true
fi

# Ensure records
ensure_a(){
  local name="$1" ip="$2"
  if ! pdnsutil list-zone "${DNS_ZONE}" | grep -E "^${name}\\s+.*A\\s+${ip}$" >/dev/null 2>&1; then
    info "Añadiendo registro A ${name} -> ${ip}"
    pdnsutil add-record "${DNS_ZONE}" "$name" A 3600 "$ip"
    pdnsutil increase-serial "${DNS_ZONE}" || true
  fi
}

ensure_a "dns" "${DNS_SERVER_IP}"
ensure_a "sv-vpn" "192.168.24.50"
ensure_a "dv-vpn" "192.168.24.20"

systemctl reload pdns || true

# Restrict recursor to allowed nets via systemd socket? Already in config allow-from

success "PowerDNS configurado"
