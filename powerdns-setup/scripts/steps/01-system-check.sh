#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

OS_OK=false
INTERNET_OK=false
DISK_OK=false
PORTS_OK=false
RAM_OK=false
ROOT_OK=false

# Comprobaciones
check_root(){
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root/sudo"
    return 1
  fi
  log_success "Permisos de root: OK"
}

check_os(){
  local ver
  ver=$(. /etc/os-release; echo "$NAME $VERSION_ID")
  if ! echo "$ver" | grep -q "Ubuntu 24.04"; then
    log_warn "SO detectado: $ver (este instalador está probado para Ubuntu 24.04)"
  else
    log_success "SO detectado: $ver"
  fi
}

check_internet(){
  if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    log_success "Conexión a Internet: OK (ping 8.8.8.8)"
  else
    log_warn "No se pudo hacer ping a 8.8.8.8"
  fi
}

check_disk(){
  local avail
  avail=$(df -Pk / | awk 'NR==2{print $4}')
  # en KB, 5GB = 5*1024*1024 = 5242880
  if [ "${avail:-0}" -ge 5242880 ]; then
    local gb=$((avail/1024/1024))
    log_success "Espacio en disco: ${gb}GB disponibles"
  else
    log_error "Espacio en disco insuficiente (<5GB)"
    return 1
  fi
}

port_free(){
  local port=$1
  ss -lntu | awk '{print $5}' | grep -E ":${port}$" >/dev/null 2>&1 && return 1 || return 0
}

check_ports(){
  local bad=0
  for p in "$PDNS_RECURSOR_PORT" "$PDNS_AUTH_PORT" "$WEBUI_PORT"; do
    if port_free "$p"; then
      log_success "Puerto ${p} disponible"
    else
      log_warn "Puerto ${p} ocupado"
      bad=$((bad+1))
    fi
  done
  [ $bad -eq 0 ]
}

check_ram(){
  local free_kb
  free_kb=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
  # 1GB = 1048576 KB
  if [ "${free_kb:-0}" -ge 1048576 ]; then
    local gb=$(awk -v kb="$free_kb" 'BEGIN{printf "%.2f", kb/1024/1024}')
    log_success "RAM disponible: ${gb}GB"
  else
    log_warn "RAM disponible < 1GB"
  fi
}

main(){
  # Encabezado visual ya lo maneja install.sh; aquí solo ejecutamos y marcamos progreso
  local rc=0
  check_root || rc=$?
  check_os || rc=$?
  check_internet || rc=$?
  check_disk || rc=$?
  check_ports || rc=$?
  check_ram || rc=$?

  if [ $rc -ne 0 ]; then
    progress_set "$STEP_KEY" "completed-with-warnings"
    return 0
  else
    progress_set "$STEP_KEY" "completed"
    return 0
  fi
}

main "$@"
