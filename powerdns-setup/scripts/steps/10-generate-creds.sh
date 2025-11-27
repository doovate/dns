#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 10: Generación de credenciales"

mkdir -p "$INSTALL_DIR" 2>/dev/null || true

# Generate missing passwords
changed=false
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  ADMIN_PASSWORD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9!@#%^&*()_+=' | head -c 24)
  changed=true
fi
if [ -z "${DB_PASSWORD:-}" ]; then
  DB_PASSWORD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9!@#%^&*()_+=' | head -c 24)
  changed=true
fi
if [ -z "${PDNS_API_KEY:-}" ]; then
  PDNS_API_KEY=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9A-Z' | head -c 32)
  changed=true
fi

# Write credentials file
cat > "$INSTALL_DIR/CREDENTIALS.txt" <<EOF
[Base de Datos]
Tipo: $DB_TYPE
Nombre: $DB_NAME
Usuario: $DB_USER
Contraseña: $DB_PASSWORD

[PowerDNS-Admin]
URL: https://$DNS_SERVER_IP:$WEBUI_PORT
Usuario: $ADMIN_USERNAME
Contraseña: $ADMIN_PASSWORD

[PowerDNS API]
URL: http://127.0.0.1:8081
API Key: $PDNS_API_KEY
EOF
run_cmd chmod 600 "$INSTALL_DIR/CREDENTIALS.txt"

log_success "Credenciales generadas y guardadas en $INSTALL_DIR/CREDENTIALS.txt"
