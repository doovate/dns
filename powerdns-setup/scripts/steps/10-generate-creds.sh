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
  local changed=false
  if [ -z "${DB_PASSWORD}" ]; then
    DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$ROOT_DIR/config.env"
    changed=true
  fi
  if [ -z "${ADMIN_PASSWORD}" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    sed -i "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=${ADMIN_PASSWORD}/" "$ROOT_DIR/config.env"
    changed=true
  fi
  if [ "$changed" = true ]; then
    log_info "Se generaron nuevas credenciales y se guardaron en config.env"
  else
    log_info "Ya existían credenciales en config.env"
  fi

  cat > "$ROOT_DIR/CREDENTIALS.txt" <<EOF
╔════════════════════════════════════════════════════════════╗
║           CREDENCIALES POWERDNS SETUP                      ║
╚════════════════════════════════════════════════════════════╝

Fecha de instalación: $(date)
Servidor: ${DNS_SERVER_IP}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BASE DE DATOS MySQL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Host: ${DB_HOST}
Puerto: ${DB_PORT}
Base de datos: ${DB_NAME}
Usuario: ${DB_USER}
Contraseña: ${DB_PASSWORD}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POWERDNS-ADMIN (Interfaz Web)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL: https://${DNS_SERVER_IP}:${NGINX_HTTPS_PORT}
Usuario: ${ADMIN_USERNAME}
Contraseña: ${ADMIN_PASSWORD}
Email: ${ADMIN_EMAIL}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SERVICIOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PowerDNS Authoritative: 127.0.0.1:${PDNS_AUTH_PORT}
PowerDNS Recursor: ${DNS_SERVER_IP}:${PDNS_RECURSOR_PORT}
PowerDNS-Admin: 127.0.0.1:${GUNICORN_PORT}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IMPORTANTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Guarda este archivo en un lugar seguro
2. Elimínalo del servidor después de guardarlo
3. Cambia las contraseñas después de la primera conexión
4. Deshabilita el registro público en PowerDNS-Admin

EOF
  chmod 600 "$ROOT_DIR/CREDENTIALS.txt"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
