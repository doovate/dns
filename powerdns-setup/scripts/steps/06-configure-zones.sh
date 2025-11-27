#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 6: Configuración de zonas DNS"

# Ensure pdnsutil exists
if ! command -v pdnsutil >/dev/null 2>&1; then
  log_error "pdnsutil no encontrado. ¿Está instalado PowerDNS Authoritative?"
  exit 20
fi

# Create zone if not exists
if pdnsutil list-all-zones | grep -q "^$DNS_ZONE$"; then
  log_info "Zona $DNS_ZONE ya existe"
else
  run_cmd pdnsutil create-zone "$DNS_ZONE" "dns.$DNS_ZONE"
fi

# Ensure NS and SOA are sensible (pdnsutil does this on create)

# Add initial A records from config variables
add_record() {
  local kv="$1"
  [ -z "$kv" ] && return 0
  local name=${kv%%:*}
  local ip=${kv#*:}
  if [ -z "$name" ] || [ -z "$ip" ]; then
    return 0
  fi
  # Check if record exists
  if pdnsutil list-zone "$DNS_ZONE" | grep -E "^$name\.$DNS_ZONE\..*A\s+$ip\b" >/dev/null 2>&1; then
    log_info "Registro A $name -> $ip ya existe"
  else
    run_cmd pdnsutil add-record "$DNS_ZONE" "$name" A 3600 "$ip"
  fi
}

add_record "${DNS_RECORD_1-}"
add_record "${DNS_RECORD_2-}"
add_record "${DNS_RECORD_3-}"

# Increase serial automatically
run_cmd pdnsutil rectify-zone "$DNS_ZONE" || true

log_success "Zona $DNS_ZONE configurada"
