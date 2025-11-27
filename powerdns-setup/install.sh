#!/bin/bash
set -euo pipefail

# =========[ PowerDNS Setup Orchestrator ]=========
# This script orchestrates a 12-step installation of a secure, production-ready
# PowerDNS stack (Authoritative + Recursor + PowerDNS-Admin + Nginx + UFW),
# driven by a user-editable config.env. It implements:
# - Dry-run mode
# - Interactive confirmations
# - Persistent progress and resumability
# - Rich logging with masking of secrets
# - Error handling with retry/skip/abort options
# - Friendly, localized messages (ES)
# ==================================================

# Change to script directory root (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh

# Global defaults (can be overridden by config.env)
INTERACTIVE_MODE=${INTERACTIVE_MODE:-true}
VERBOSE_MODE=${VERBOSE_MODE:-true}
ENABLE_LOGGING=${ENABLE_LOGGING:-true}
LOG_FILE=${LOG_FILE:-/var/log/powerdns-setup.log}
DRY_RUN=false
RESUME=true

# Load configuration
if [ -f config.env ]; then
  # shellcheck disable=SC1091
  source config.env
else
  echo "No se encontró config.env. Por favor, copia y edita powerdns-setup/config.env antes de instalar."
  exit 1
fi

# Steps definition
TOTAL_STEPS=12
# Format: file_id:Human readable title
STEPS=(
  "01-system-check:Verificación del sistema"
  "02-install-deps:Instalación de dependencias"
  "03-setup-db:Configuración de base de datos"
  "04-install-pdns-auth:Instalación PowerDNS Authoritative"
  "05-install-pdns-recursor:Instalación PowerDNS Recursor"
  "06-configure-zones:Configuración de zonas DNS"
  "07-install-pdns-admin:Instalación PowerDNS-Admin"
  "08-setup-nginx:Configuración de nginx"
  "09-setup-firewall:Configuración de firewall"
  "10-generate-creds:Generación de credenciales"
  "11-start-services:Inicio de servicios"
  "12-final-tests:Pruebas finales"
)

print_usage() {
  cat <<USAGE
Instalador PowerDNS - Opciones:
  --dry-run              Muestra lo que se haría sin ejecutar cambios
  --non-interactive      No solicita confirmaciones (equivale a INTERACTIVE_MODE=false)
  --verbose              Muestra comandos antes de ejecutar
  --quiet                Menos salida (equivale a VERBOSE_MODE=false)
  --no-resume            Ignora progreso previo y reinicia instalación
  --help                 Muestra esta ayuda
USAGE
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --non-interactive) INTERACTIVE_MODE=false ;;
      --verbose) VERBOSE_MODE=true ;;
      --quiet) VERBOSE_MODE=false ;;
      --no-resume) RESUME=false ;;
      --help|-h) print_usage; exit 0 ;;
      *) echo "Opción no reconocida: $1"; print_usage; exit 1 ;;
    esac
    shift
  done
}

# Execute a step by id:name
execute_step() {
  local spec="$1"
  local step_id="${spec%%:*}"
  local step_name="${spec#*:}"
  local step_script="scripts/steps/${step_id}.sh"

  if ! [ -f "$step_script" ]; then
    log_error "No se encontró el script del paso: $step_script"
    return 1
  fi

  if is_step_completed "$step_id"; then
    show_step_skipped "$step_name"
    return 0
  fi

  show_step_info "$step_name"

  if [ "$INTERACTIVE_MODE" = "true" ]; then
    ask_continue || { show_step_skipped "$step_name"; return 0; }
  fi

  if bash "$step_script"; then
    mark_step_completed "$step_id"
    show_step_success "$step_name"
  else
    local exit_code=$?
    show_step_error "$step_name" "$exit_code"
    handle_error "$step_id" "$exit_code" "$step_name" "$step_script"
  fi
}

main() {
  parse_arguments "$@"
  init_logging "$ENABLE_LOGGING" "$LOG_FILE" "$VERBOSE_MODE" "$DRY_RUN"
  load_progress "$RESUME"
  show_banner

  log_info "Iniciando instalación con TOTAL_STEPS=$TOTAL_STEPS, DRY_RUN=$DRY_RUN, INTERACTIVE=$INTERACTIVE_MODE"

  local i=1
  for step in "${STEPS[@]}"; do
    update_progress_visual $i $TOTAL_STEPS "${step#*:}"
    execute_step "$step"
    i=$((i+1))
  done

  show_summary "$TOTAL_STEPS"
}

main "$@"
