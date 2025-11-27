#!/usr/bin/env bash
# Gestión de progreso .install_progress y utilidades de paso

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
PROGRESS_FILE="$ROOT_DIR/.install_progress"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/logging.sh"

progress_init(){
  if [ ! -f "$PROGRESS_FILE" ]; then
    echo "# Archivo de progreso de instalación" > "$PROGRESS_FILE"
  fi
}

progress_set(){
  local key="$1"; local value="$2"
  progress_init
  # eliminar línea existente
  if grep -q "^${key}=" "$PROGRESS_FILE" 2>/dev/null; then
    sed -i "s#^${key}=.*#${key}=${value}#" "$PROGRESS_FILE"
  else
    echo "${key}=${value}" >> "$PROGRESS_FILE"
  fi
  log_info "Estado actualizado: ${key}=${value}"
}

progress_get(){
  local key="$1"
  if [ -f "$PROGRESS_FILE" ]; then
    grep -E "^${key}=" "$PROGRESS_FILE" | head -n1 | cut -d'=' -f2-
  fi
}

progress_reset(){
  rm -f "$PROGRESS_FILE"
  progress_init
  log_warn "Progreso reiniciado"
}

step_prompt(){
  local title="$1"; local status="$2"; local description="$3"
  echo
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  ${title}"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo "Estado actual: [ ${status} ]"
  echo
  echo -e "$description"
  echo
  if [ "$AUTO_MODE" = true ]; then
    REPLY="s"
  else
    read -r -p "¿Continuar con este paso? [S/n]: " REPLY
  fi
  [[ -z "$REPLY" || "$REPLY" =~ ^[sS]$ ]]
}

step_run(){
  local step_id="$1"; shift
  local cmd="$*"
  local rc=0
  if [ "$DRY_RUN" = true ]; then
    log_info "DRY-RUN: ${step_id} se marcaría como completed"
    progress_set "$step_id" "completed"
    return 0
  fi
  eval "$cmd"
  rc=$?
  if [ $rc -eq 0 ]; then
    progress_set "$step_id" "completed"
    log_success "${step_id} completado"
    return 0
  else
    progress_set "$step_id" "failed:$rc"
    return $rc
  fi
}
