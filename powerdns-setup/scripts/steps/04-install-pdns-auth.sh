#!/usr/bin/env bash
set -Eeuo pipefail

# Paso 04: Instalación y configuración de PowerDNS Authoritative
# - Render de /etc/powerdns/pdns.conf desde template
# - Configuración de backend PostgreSQL
# - API habilitada con api-key
# - Habilitar e iniciar servicio

source "$REPO_ROOT/scripts/lib/logging.sh"

escape_sed() { echo "$1" | sed -e 's/[\/&]/\\&/g'; }

gen_api_key() { openssl rand -hex 24; }

main() {
  if ! command -v pdns_server >/dev/null 2>&1; then
    log_error "pdns_server no está instalado. Ejecuta el paso 02."
    exit 30
  fi

  # Asegurar directorios
  sudo mkdir -p /etc/powerdns
  sudo chown root:root /etc/powerdns

  # api-key
  if [[ -z "${PDNS_API_KEY:-}" ]]; then
    PDNS_API_KEY=$(gen_api_key)
    export PDNS_API_KEY
    log_info "Generada PDNS_API_KEY (oculta en logs)."
  fi

  # Render template
  local tpl="$REPO_ROOT/configs/pdns.conf.template"
  if [[ ! -f "$tpl" ]]; then
    log_error "No se encuentra el template pdns.conf.template"
    exit 31
  fi
  local out="/etc/powerdns/pdns.conf"
  sed \
    -e "s/{{PDNS_AUTH_PORT}}/$(escape_sed "$PDNS_AUTH_PORT")/g" \
    -e "s/{{PDNS_API_KEY}}/$(escape_sed "$PDNS_API_KEY")/g" \
    -e "s/{{DB_USER}}/$(escape_sed "$DB_USER")/g" \
    -e "s/{{DB_NAME}}/$(escape_sed "$DB_NAME")/g" \
    -e "s/{{DB_PASSWORD}}/$(escape_sed "$DB_PASSWORD")/g" \
    "$tpl" | sudo tee "$out" >/dev/null

  sudo chmod 640 "$out"
  sudo chown root:pdns "$out"

  # Habilitar e iniciar
  log_cmd systemctl enable pdns
  if ! log_cmd systemctl restart pdns; then
    log_error "Fallo al iniciar pdns. Mostrando últimos logs:"
    journalctl -xeu pdns.service | tail -n 50 || true
    exit 32
  fi

  # Comprobación básica
  sleep 1
  if ! systemctl is-active --quiet pdns; then
    log_error "pdns no está activo tras el arranque."
    journalctl -u pdns --no-pager | tail -n 50 || true
    exit 33
  fi
  log_info "PowerDNS Authoritative configurado y en ejecución."
}

main "$@"
