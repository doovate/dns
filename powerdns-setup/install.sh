#!/usr/bin/env bash
set -euo pipefail

# Colors and logging
info() { echo -e "\e[34m[INFO]\e[0m $*"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $*"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }
error() { echo -e "\e[31m[ERROR]\e[0m $*"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Ensure config exists and generate secrets before loading
test -f "$ROOT_DIR/config.env" || { error "config.env no encontrado"; exit 1; }
# Generate strong secrets if defaults are present (idempotent)
bash "$ROOT_DIR/scripts/generate-secrets.sh"

# Load config after potential updates
set -a; source "$ROOT_DIR/config.env"; set +a

# Ensure scripts executable
chmod +x scripts/*.sh || true

confirm() {
  local msg=${1:-"¿Continuar?"}
  if [[ "${AUTO_APPROVE}" == "true" ]]; then return 0; fi
  read -rp "$msg [y/N]: " ans || true
  [[ "$ans" =~ ^[Yy]$ ]]
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    error "Este script debe ejecutarse como root (use sudo)."; exit 1
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$NAME" != "Ubuntu" || "$VERSION_ID" != "24.04"* ]]; then
      warn "Sistema detectado: $NAME $VERSION_ID. Este instalador está optimizado para Ubuntu 24.04 LTS." 
    fi
  fi
}

apt_install() {
  local pkgs=("$@")
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

setup_firewall() {
  if [[ "$ENABLE_UFW" != "true" ]]; then
    warn "UFW deshabilitado por configuración"; return 0
  fi
  if ! command -v ufw >/dev/null 2>&1; then apt_install ufw; fi
  ufw allow OpenSSH || true
  ufw allow ${RECURSOR_PORT}/udp || true
  ufw allow ${RECURSOR_PORT}/tcp || true
  ufw allow ${AUTHORITATIVE_PORT}/tcp || true
  ufw allow ${PDNSA_HTTP_PORT}/tcp || true
  ufw allow ${NGINX_HTTP_PORT}/tcp || true
  ufw allow ${NGINX_HTTPS_PORT}/tcp || true
  yes | ufw enable || true
}

main() {
  require_root
  check_os
  info "Instalando prerequisitos del sistema"
  apt_install curl wget gnupg lsb-release ca-certificates jq git make build-essential python3 python3-venv python3-pip virtualenv \
              nginx openssl bind9-dnsutils logrotate cron \
              postgresql postgresql-contrib postgresql-client \
              pdns-server pdns-backend-pgsql pdns-recursor

  info "Configurando base de datos"
  bash scripts/setup-db.sh

  info "Configurando PowerDNS (authoritative y recursor)"
  bash scripts/setup-pdns.sh

  info "Configurando PowerDNS-Admin y Nginx"
  bash scripts/setup-admin.sh

  info "Configurando firewall"
  setup_firewall

  info "Ejecución de pruebas básicas"
  bash scripts/test-dns.sh || { warn "Pruebas mostraron advertencias"; }

  success "Instalación completada. Consulte docs/USAGE.md para uso de la interfaz."
}

main "$@"
