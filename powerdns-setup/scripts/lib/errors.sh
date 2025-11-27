#!/usr/bin/env bash
# Manejo de errores interactivo con sugerencias y reintentos

# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"

show_error_dialog(){
  local step_title="$1"
  local step_key="$2"
  local cmd="$3"
  local rc="$4"
  local captured_error="$5"
  local suggestions="$6"

  echo
  echo "❌ ERROR EN ${step_title}"
  echo
  echo "Comando fallido:"
  echo "$cmd"
  echo
  echo "Código de salida: $rc"
  echo
  echo "Error capturado:"
  echo -e "$captured_error"
  echo
  if [ -n "$suggestions" ]; then
    echo "Sugerencias:"
    echo -e "$suggestions"
  fi
  echo
  if [ "$AUTO_MODE" = true ]; then
    log_warn "AUTO_MODE activo: abortando instalación por fallo en ${step_key}"
    return 2
  fi
  local opt
  while true; do
    read -r -p "¿Qué deseas hacer? [R]eintentar / [S]altar / [M]odificar / [A]bortar / [L]og: " opt
    opt="${opt:-R}"
    case "$opt" in
      R|r) return 0;;
      S|s) progress_set "$step_key" "skipped"; return 3;;
      M|m) echo "Abre otra terminal para corregir el problema y vuelve. Pulsa ENTER para reintentar..."; read -r; return 0;;
      A|a) return 2;;
      L|l) echo -e "$captured_error" | less; ;;
      *) echo "Opción no válida";;
    esac
  done
}

# Ejecutar comando con captura de errores y diálogo
run_or_recover(){
  local step_title="$1"; shift
  local step_key="$1"; shift
  local cmd="$*"
  local attempt=1
  while true; do
    local output rc
    if [ "$DRY_RUN" = true ]; then
      log_info "DRY-RUN: $cmd"
      return 0
    fi
    output=$(eval "$cmd" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
      [ -n "$output" ] && log_debug "$output"
      return 0
    fi
    log_error "Fallo intento #$attempt en ${step_key}: rc=$rc"
    log_error "$output"

    local suggestions="- Verifica conexión a Internet\n- Ejecuta 'apt update'\n- Revisa nombres de paquetes para Ubuntu 24.04"
    show_error_dialog "$step_title" "$step_key" "$cmd" "$rc" "$output" "$suggestions"
    case $? in
      0) attempt=$((attempt+1));; # reintentar
      2) return 2;;               # abortar
      3) return 3;;               # saltar
      *) attempt=$((attempt+1));; 
    esac
  done
}
