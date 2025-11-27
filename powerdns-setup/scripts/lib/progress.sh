#!/usr/bin/env bash
# Progress tracking stored in .install_progress

ensure_progress_file() {
  [[ -f "$INSTALL_PROGRESS_FILE" ]] || echo "" > "$INSTALL_PROGRESS_FILE"
}

load_progress() {
  ensure_progress_file
}

reset_progress() {
  rm -f "$INSTALL_PROGRESS_FILE"
  touch "$INSTALL_PROGRESS_FILE"
}

_set_step_status() {
  local step="$1"; local status="$2"; local detail="${3:-}"
  ensure_progress_file
  # Remove existing line for this step
  grep -v -E "^STEP_${step}=" "$INSTALL_PROGRESS_FILE" >"$INSTALL_PROGRESS_FILE.tmp" 2>/dev/null || true
  mv "$INSTALL_PROGRESS_FILE.tmp" "$INSTALL_PROGRESS_FILE" 2>/dev/null || true
  if [[ -n "$detail" ]]; then
    echo "STEP_${step}=${status}:${detail}" >> "$INSTALL_PROGRESS_FILE"
  else
    echo "STEP_${step}=${status}" >> "$INSTALL_PROGRESS_FILE"
  fi
}

mark_step_completed() { _set_step_status "$1" completed; }
mark_step_pending() { _set_step_status "$1" pending; }
mark_step_failed() { _set_step_status "$1" failed "$2"; }

is_step_completed() {
  local step="$1"
  [[ -f "$INSTALL_PROGRESS_FILE" ]] || return 1
  grep -q -E "^STEP_${step}=completed" "$INSTALL_PROGRESS_FILE"
}

show_step_status() {
  local step="$1"
  local val=""
  if [[ -f "$INSTALL_PROGRESS_FILE" ]]; then
    val=$(grep -E "^STEP_${step}=" "$INSTALL_PROGRESS_FILE" | head -n1 | cut -d'=' -f2- || true)
  fi
  if [[ -z "$val" ]]; then
    echo "Estado actual: [ PENDIENTE ]"
  else
    case "$val" in
      completed*) echo "Estado actual: [ COMPLETADO ]" ;;
      failed*) echo "Estado actual: [ FALLÓ ] ($val)" ;;
      pending*) echo "Estado actual: [ PENDIENTE ]" ;;
      *) echo "Estado actual: [ $val ]" ;;
    esac
  fi
}

count_steps_by_status() {
  local status="$1"
  [[ -f "$INSTALL_PROGRESS_FILE" ]] || { echo 0; return; }
  grep -c -E "=${status}(=|:|$)" "$INSTALL_PROGRESS_FILE" || echo 0
}

list_steps_summary() {
  echo "Resumen de pasos:"
  if [[ ! -s "$INSTALL_PROGRESS_FILE" ]]; then
    echo "  (sin datos)"
    return
  fi
  sort "$INSTALL_PROGRESS_FILE" | sed -E 's/^STEP_([0-9]{2}-[^=]+)=(.*)$/  \1 -> \2/'
}
