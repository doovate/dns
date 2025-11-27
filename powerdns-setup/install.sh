#!/usr/bin/env bash
set -Eeuo pipefail

# PowerDNS Setup - Instalación Paso a Paso con Control Total
# Orquestador principal: ejecuta 12 pasos independientes, con control interactivo,
# logging detallado, manejo de errores y reanudación mediante .install_progress

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

# Cargar configuración (si existe) y librerías
if [[ -f config.env ]]; then
  # shellcheck disable=SC1091
  source config.env
fi

mkdir -p scripts/lib scripts/steps configs configs/zones
INSTALL_PROGRESS_FILE="${REPO_ROOT}/.install_progress"
CREDENTIALS_FILE="${REPO_ROOT}/CREDENTIALS.txt"

# Valores por defecto si no están en config.env
DNS_SERVER_IP=${DNS_SERVER_IP:-192.168.25.60}
INTERNAL_NETWORK=${INTERNAL_NETWORK:-192.168.24.0/22}
VPN_NETWORK=${VPN_NETWORK:-10.66.66.0/24}
DNS_ZONE=${DNS_ZONE:-doovate.com}
DNS_FORWARDER_1=${DNS_FORWARDER_1:-8.8.8.8}
DNS_FORWARDER_2=${DNS_FORWARDER_2:-1.1.1.1}
PDNS_AUTH_PORT=${PDNS_AUTH_PORT:-5300}
PDNS_RECURSOR_PORT=${PDNS_RECURSOR_PORT:-53}
WEBUI_PORT=${WEBUI_PORT:-9191}
DB_TYPE=${DB_TYPE:-postgresql}
DB_NAME=${DB_NAME:-powerdns}
DB_USER=${DB_USER:-pdns}
DB_PASSWORD=${DB_PASSWORD:-}
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@doovate.com}
INTERACTIVE_MODE=${INTERACTIVE_MODE:-true}
VERBOSE_MODE=${VERBOSE_MODE:-true}
ENABLE_LOGGING=${ENABLE_LOGGING:-true}
LOG_FILE=${LOG_FILE:-/var/log/powerdns-setup.log}
DRY_RUN=${DRY_RUN:-false}

# Exportar para que los pasos los vean
export REPO_ROOT INSTALL_PROGRESS_FILE CREDENTIALS_FILE \
  DNS_SERVER_IP INTERNAL_NETWORK VPN_NETWORK DNS_ZONE DNS_FORWARDER_1 DNS_FORWARDER_2 \
  PDNS_AUTH_PORT PDNS_RECURSOR_PORT WEBUI_PORT DB_TYPE DB_NAME DB_USER DB_PASSWORD \
  ADMIN_USERNAME ADMIN_PASSWORD ADMIN_EMAIL INTERACTIVE_MODE VERBOSE_MODE \
  ENABLE_LOGGING LOG_FILE DRY_RUN

# Cargar libs
for lib in colors logging progress errors; do
  # shellcheck disable=SC1090
  [[ -f "scripts/lib/${lib}.sh" ]] && source "scripts/lib/${lib}.sh"
done

show_banner() {
  echo "$(title_border)"
  echo "$(title_line)   PowerDNS Setup Paso a Paso v1.0"
  echo "$(title_line)   Ubuntu 24.04 LTS"
  echo "$(title_border)"
}

usage() {
  cat <<USAGE
Uso:
  sudo bash install.sh [--auto] [--resume] [--reset] [--dry-run]

Opciones:
  --auto       Modo automático (no preguntar confirmaciones)
  --resume     Reanudar desde estado previo (por defecto si existe progreso)
  --reset      Borrar progreso y reiniciar instalación
  --dry-run    Simulación: mostrar qué se haría sin ejecutar
USAGE
}

AUTO_MODE=false
RESUME=false
RESET=false

parse_arguments() {
  for arg in "$@"; do
    case "$arg" in
      --auto) AUTO_MODE=true; INTERACTIVE_MODE=false ;;
      --resume) RESUME=true ;;
      --reset) RESET=true ;;
      --dry-run) DRY_RUN=true ;;
      -h|--help) usage; exit 0 ;;
      *) ;;
    esac
  done
}

# Definición de pasos (archivo + título)
TOTAL_STEPS=12
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

ask_continue() {
  if [[ "$AUTO_MODE" == true || "$INTERACTIVE_MODE" != true ]]; then
    return 0
  fi
  read -r -p "¿Continuar con este paso? [S/n]: " ans || true
  [[ -z "$ans" || "$ans" =~ ^[sS]$ ]]
}

show_step_header() {
  local idx=$1
  local title=$2
  echo "$(title_border)"
  printf "║  %s PASO %d/%d: %s %-*s║\n" "$(bold)" "$idx" "$TOTAL_STEPS" "$title" $((44-${#title})) "$(normal)"
  echo "$(title_border)"
}

progress_bar() {
  local current=$1 total=$2 label=$3
  local width=24
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  printf "[%s%s] %d%% (%d/%d) - %s\n" \
    "$(printf '█%.0s' $(seq 1 $filled))" "$(printf '░%.0s' $(seq 1 $empty))" \
    $(( current * 100 / total )) "$current" "$total" "$label"
}

execute_step() {
  local step_key="$1"; local step_file; step_file="${step_key%%:*}"; local step_title; step_title="${step_key#*:}"
  local idx="$2"
  show_step_header "$idx" "$step_title"
  show_step_status "$step_file"

  if is_step_completed "$step_file"; then
    show_step_skipped "$step_title"
    return 0
  fi

  if ! ask_continue; then
    mark_step_pending "$step_file"
    echo "Saltado por el usuario."
    return 0
  fi

  local script_path="scripts/steps/${step_file}.sh"
  if [[ ! -x "$script_path" ]]; then
    log_error "El script de paso no existe: $script_path"
    mark_step_failed "$step_file" "script_not_found"
    return 1
  fi

  progress_bar "$idx" "$TOTAL_STEPS" "$step_title..."

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Ejecutaría: $script_path"
    mark_step_completed "$step_file"
    show_step_success "$step_title"
    return 0
  fi

  if bash "$script_path"; then
    mark_step_completed "$step_file"
    show_step_success "$step_title"
  else
    local exit_code=$?
    show_step_error "$step_title" "$exit_code"
    handle_error "$step_file" "$exit_code"
  fi
}

show_summary() {
  echo "$(title_border)"
  echo "$(title_line)           RESUMEN DE INSTALACIÓN"
  echo "$(title_border)"
  local completed=$(count_steps_by_status completed)
  echo "Pasos completados: ${completed}/${TOTAL_STEPS}"
  list_steps_summary
  echo ""
  echo "🌐 Acceso a PowerDNS-Admin:"
  echo "   URL: https://${DNS_SERVER_IP}:${WEBUI_PORT}"
  echo "   Usuario: ${ADMIN_USERNAME}"
  echo "   Contraseña: [ver CREDENTIALS.txt]"
  echo ""
  echo "📄 Credenciales: ${CREDENTIALS_FILE}"
  echo "📊 Log de instalación: ${LOG_FILE}"
}

main() {
  parse_arguments "$@"
  [[ "$RESET" == true ]] && reset_progress
  load_progress
  init_logging
  show_banner

  local i=0
  for step in "${STEPS[@]}"; do
    i=$((i+1))
    execute_step "$step" "$i"
  done
  show_summary
}

main "$@"
