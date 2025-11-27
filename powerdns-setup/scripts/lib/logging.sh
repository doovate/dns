#!/usr/bin/env bash
# Sistema de logging con niveles y archivo de log
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

LOG_FILE_DEFAULT="/var/log/powerdns-setup.log"

# shellcheck disable=SC1091
[ -f "$ROOT_DIR/config.env" ] && source "$ROOT_DIR/config.env"

LOG_FILE=${LOG_FILE:-${LOG_FILE_DEFAULT}}
ENABLE_LOGGING=${ENABLE_LOGGING:-true}
VERBOSE_MODE=${VERBOSE_MODE:-true}

_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

_log_write(){
  local level="$1"; shift
  local msg="$*"
  local line="[$(_timestamp)] [$level] $msg"
  if [ "$ENABLE_LOGGING" = true ]; then
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo -e "$line" >> "$LOG_FILE" 2>/dev/null || true
  fi
  # Imprimir siempre a stdout si VERBOSE o si es WARNING/ERROR
  if [ "$VERBOSE_MODE" = true ] || [ "$level" != "DEBUG" ]; then
    echo -e "$line"
  fi
}

log_debug(){ _log_write "DEBUG" "$*"; }
log_info(){ _log_write "INFO" "$*"; }
log_warn(){ _log_write "WARN" "$*"; }
log_error(){ _log_write "ERROR" "$*"; }
log_success(){ _log_write "SUCCESS" "$*"; }

# Ejecuta un comando mostrando el comando, captura salida y código
log_cmd(){
  local cmd="$*"
  log_info "[Ejecutando] $cmd"
  if [ "$DRY_RUN" = true ]; then
    log_info "DRY-RUN: no se ejecutó el comando"
    return 0
  fi
  # Ejecutar y capturar salida/estado
  local output
  output=$(eval "$cmd" 2>&1)
  local rc=$?
  if [ $rc -ne 0 ]; then
    log_error "Comando fallido ($rc): $cmd"
    log_error "Salida:\n$output"
    return $rc
  else
    [ -n "$output" ] && log_debug "$output"
    return 0
  fi
}
