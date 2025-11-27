#!/bin/bash
# Logging, command execution helpers (masking secrets), and global flags
# Requires: colors.sh

LOG_ENABLED=true
LOG_PATH=/var/log/powerdns-setup.log
LOG_VERBOSE=true
DRY_RUN=false

# Initialize logging parameters from main
init_logging() {
  LOG_ENABLED=$1
  LOG_PATH=$2
  LOG_VERBOSE=$3
  DRY_RUN=$4

  if [ "$LOG_ENABLED" = "true" ]; then
    # Try to create log file directory
    local dir
    dir=$(dirname "$LOG_PATH")
    if [ ! -d "$dir" ]; then
      mkdir -p "$dir" 2>/dev/null || true
    fi
    # Touch log file
    : > "$LOG_PATH" 2>/dev/null || true
  fi
}

_now_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Mask potential secrets in command strings and outputs
_mask() {
  local s="$*"
  # Known sensitive vars
  for key in DB_PASSWORD ADMIN_PASSWORD PDNS_API_KEY; do
    local val="${!key-}"
    if [ -n "$val" ]; then
      s=${s//$val/******}
    fi
  done
  echo "$s"
}

_log_write() {
  local level="$1"; shift
  local msg="$*"
  local line="[$(_now_ts)] [$level] $msg"
  if [ "$LOG_ENABLED" = "true" ]; then
    echo "$line" >> "$LOG_PATH" 2>/dev/null || true
  fi
}

log_info() { color_info "[INFO] $*"; _log_write INFO "$*"; }
log_warn() { color_warn "[WARN] $*"; _log_write WARN "$*"; }
log_error() { color_error "[ERROR] $*"; _log_write ERROR "$*"; }
log_success() { color_success "[OK] $*"; _log_write OK "$*"; }

# Log a command, execute it, capture output and exit code
# Usage: run_cmd "apt update" or run_cmd sudo systemctl restart pdns
run_cmd() {
  local cmd_str
  cmd_str="$*"
  local masked
  masked=$(_mask "$cmd_str")

  if [ "$LOG_VERBOSE" = "true" ]; then
    echo -e "${DIM}$ ${masked}${NC}"
  fi
  _log_write CMD "$masked"

  if [ "$DRY_RUN" = "true" ]; then
    _log_write DRYRUN "Skipped (dry-run): $masked"
    return 0
  fi

  # Execute capturing stdout+stderr to log while mirroring live
  local output
  set +e
  output=$(eval "$cmd_str" 2>&1)
  local exit_code=$?
  set -e
  local masked_out
  masked_out=$(_mask "$output")
  if [ -n "$masked_out" ]; then
    _log_write OUT "$masked_out"
  fi
  if [ $exit_code -ne 0 ]; then
    _log_write EXIT "Exit $exit_code for: $masked"
  fi
  echo "$masked_out" | sed '/^\s*$/d' >/dev/null 2>&1 || true
  return $exit_code
}

show_full_log() {
  if [ "$LOG_ENABLED" != "true" ]; then
    echo "Logging deshabilitado."
    return 0
  fi
  if [ -f "$LOG_PATH" ]; then
    echo "--- LOG COMPLETO ($LOG_PATH) ---"
    cat "$LOG_PATH"
    echo "--- FIN LOG ---"
  else
    echo "No hay log disponible en $LOG_PATH"
  fi
}
