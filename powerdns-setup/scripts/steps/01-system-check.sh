#!/usr/bin/env bash
set -Eeuo pipefail

# Paso 01: Verificación del sistema
# - Root/sudo
# - Ubuntu 24.04
# - Conexión a Internet
# - Espacio en disco
# - Puertos disponibles (53, 5300, WEBUI_PORT)

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"
source "$REPO_ROOT/scripts/lib/colors.sh"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root (sudo)."
    exit 2
  fi
}

check_os() {
  if ! command -v lsb_release >/dev/null 2>&1; then
    log_info "Instalando lsb-release..."
    log_cmd apt-get update -y
    log_cmd apt-get install -y lsb-release
  fi
  local dist=$(lsb_release -si 2>/dev/null || echo "Ubuntu")
  local rel=$(lsb_release -sr 2>/dev/null || echo "24.04")
  if [[ "$dist" != "Ubuntu" || "${rel%%.*}" != "24" ]]; then
    log_error "Se requiere Ubuntu 24.04. Detectado: $dist $rel"
    exit 3
  fi
  log_info "SO detectado: $dist $rel"
}

check_internet() {
  if command -v ping >/dev/null 2>&1; then
    if ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
      log_info "Conexión a Internet: OK (ping 8.8.8.8)"
    else
      log_warn "No se pudo hacer ping a 8.8.8.8. Intentando curl a http://example.com"
      if ! curl -I --max-time 5 http://example.com >/dev/null 2>&1; then
        log_error "Sin conectividad de red."
        exit 4
      else
        log_info "Conectividad HTTP verificada."
      fi
    fi
  else
    log_cmd apt-get update -y
    log_cmd apt-get install -y iputils-ping
    check_internet
  fi
}

check_disk() {
  local avail_kb=$(df -Pk "$REPO_ROOT" | awk 'NR==2{print $4}')
  local min_kb=$((5*1024*1024))
  if (( avail_kb < min_kb )); then
    log_error "Espacio en disco insuficiente (<5GB) en $REPO_ROOT"
    exit 5
  fi
  local avail_gb=$(( avail_kb / 1024 / 1024 ))
  log_info "Espacio en disco: ${avail_gb}GB disponibles"
}

port_free() {
  local port="$1"
  ss -lntup 2>/dev/null | grep -q ":${port}\b" && return 1 || return 0
}

check_ports() {
  for port in "$PDNS_RECURSOR_PORT" "$PDNS_AUTH_PORT" "$WEBUI_PORT"; do
    if port_free "$port"; then
      log_info "Puerto $port disponible"
    else
      log_warn "Puerto $port en uso. Se deberá reconfigurar o detener el proceso que lo usa."
    fi
  done
}

main() {
  require_root
  check_os
  check_internet
  check_disk
  check_ports
}

main "$@"
