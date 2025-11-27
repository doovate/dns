#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 1: Verificación del sistema"

# Root check
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  log_error "Este script debe ejecutarse como root o con sudo."
  exit 2
fi

# OS check (Ubuntu 24.04)
if command -v lsb_release >/dev/null 2>&1; then
  DISTRO=$(lsb_release -is)
  RELEASE=$(lsb_release -rs)
else
  DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
  RELEASE=$(grep ^VERSION_ID= /etc/os-release | cut -d= -f2 | tr -d '"')
fi
log_info "Sistema detectado: $DISTRO $RELEASE"
if [[ "$DISTRO" != "Ubuntu" || "$RELEASE" != 24.04* ]]; then
  log_warn "Este instalador está validado para Ubuntu 24.04. Continuando de todos modos."
fi

# Internet connectivity
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  log_success "Conectividad a Internet OK"
else
  log_warn "No se pudo verificar la conectividad a Internet (8.8.8.8)."
fi

# Disk space check
REQUIRED_MB=2048
AVAILABLE_MB=$(df -Pm / | awk 'NR==2{print $4}')
log_info "Espacio disponible: ${AVAILABLE_MB}MB"
if [ "$AVAILABLE_MB" -lt "$REQUIRED_MB" ]; then
  log_error "Espacio insuficiente (< ${REQUIRED_MB}MB en /)"
  exit 3
fi

# Port availability
check_port() {
  local port="$1"
  if ss -lnt 2>/dev/null | awk '{print $4}' | grep -q ":$port$"; then
    return 1
  fi
  return 0
}

if ! check_port "$PDNS_RECURSOR_PORT"; then
  log_warn "El puerto $PDNS_RECURSOR_PORT parece estar en uso."
fi
if ! check_port "$PDNS_AUTH_PORT"; then
  log_warn "El puerto $PDNS_AUTH_PORT parece estar en uso."
fi
if ! check_port "$WEBUI_PORT"; then
  log_warn "El puerto $WEBUI_PORT parece estar en uso."
fi

log_success "Verificación del sistema completada"
