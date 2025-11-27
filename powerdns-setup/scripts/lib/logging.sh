#!/usr/bin/env bash
# Centralized logging utilities with optional file logging and command runner

init_logging() {
  if [[ "${ENABLE_LOGGING:-true}" == true ]]; then
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    sudo touch "$LOG_FILE" 2>/dev/null || true
    sudo chmod 640 "$LOG_FILE" 2>/dev/null || true
  fi
}

ts() { date '+%Y-%m-%d %H:%M:%S'; }

_mask_secrets() {
  sed -E \
    -e "s/(password=)[^ ']+/\1********/Ig" \
    -e "s/(DB_PASSWORD=)[^ ']+/\1********/Ig" \
    -e "s/(API[_A-Z]*=)[^ ']+/\1********/Ig"
}

_log() {
  local level="$1"; shift
  local msg="$*"
  local line="[$(ts)] [$level] $msg"
  if command -v tput >/dev/null 2>&1; then
    case "$level" in
      INFO) printf "%s%s%s\n" "$(green)" "$line" "$(normal)" ;;
      WARN) printf "%s%s%s\n" "$(yellow)" "$line" "$(normal)" ;;
      ERROR) printf "%s%s%s\n" "$(red)" "$line" "$(normal)" ;;
      *) echo "$line" ;;
    esac
  else
    echo "$line"
  fi
  if [[ "${ENABLE_LOGGING:-true}" == true ]]; then
    echo "$line" | _mask_secrets | sudo tee -a "$LOG_FILE" >/dev/null || true
  fi
}

log_info() { _log INFO "$*"; }
log_warn() { _log WARN "$*"; }
log_error() { _log ERROR "$*"; }

# Run a command with logging. If VERBOSE_MODE, echo the command first.
# Usage: log_cmd <cmd...>
log_cmd() {
  if [[ "${VERBOSE_MODE:-true}" == true ]]; then
    log_info "Ejecutando: $*"
  fi
  if [[ "${DRY_RUN:-false}" == true ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@" 2> >(while read -r line; do log_error "$line"; done) | while read -r line; do log_info "$line"; done
  return ${PIPESTATUS[0]}
}
