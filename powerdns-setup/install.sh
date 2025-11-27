#!/usr/bin/env bash
# Instalador interactivo PowerDNS para Ubuntu 24.04
# Ejecuta pasos uno a uno, reanudable, con archivo de progreso
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib/colors.sh"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

CONFIG_FILE="$ROOT_DIR/config.env"
PROGRESS_FILE="$ROOT_DIR/.install_progress"

usage(){
  cat <<EOF
Uso: sudo bash install.sh [--auto] [--reset] [--resume] [--dry-run]

Opciones:
  --auto      Ejecuta en modo automático sin pausas
  --reset     Reinicia el progreso y comienza desde cero
  --resume    Continúa desde donde se quedó
  --dry-run   Muestra lo que haría sin ejecutar cambios
EOF
}

# Flags
AUTO_MODE=false
RESET=false
RESUME=false
DRY_RUN=${DRY_RUN:-false}

# Activar AUTO_MODE si no hay TTY (no interactivo)
if [ ! -t 0 ]; then AUTO_MODE=true; fi

for arg in "$@"; do
  case "$arg" in
    --auto) AUTO_MODE=true ;;
    --reset) RESET=true ;;
    --resume) RESUME=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción no reconocida: $arg"; usage; exit 1 ;;
  esac
done

# Cargar configuración
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Falta $CONFIG_FILE. Copia y edita antes de continuar." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Mensaje de bienvenida y modo
echo "Iniciando instalador de PowerDNS (AUTO_MODE=${AUTO_MODE}, DRY_RUN=${DRY_RUN})"

# Aplicar DRY_RUN/AUTO_MODE al entorno de logs
export DRY_RUN AUTO_MODE VERBOSE_MODE ENABLE_LOGGING LOG_FILE

# Reset/resume
if [ "$RESET" = true ]; then
  progress_reset
fi
progress_init

# Registrar pasos
STEPS=(
  "01:01-system-check:Verificación del sistema"
  "02:02-install-deps:Instalación de dependencias base"
  "03:03-setup-db:Configuración de base de datos"
  "04:04-install-pdns-auth:Instalación PowerDNS Authoritative"
  "05:05-install-pdns-recursor:Instalación PowerDNS Recursor"
  "06:06-configure-zones:Configuración de zonas DNS"
  "07:07-install-pdns-admin:Instalación PowerDNS-Admin"
  "08:08-setup-nginx:Configuración Nginx + SSL"
  "09:09-setup-firewall:Configuración Firewall"
  "10:10-generate-creds:Generación de credenciales"
  "11:11-start-services:Inicio de servicios"
  "12:12-final-tests:Pruebas finales"
)

TOTAL=${#STEPS[@]}
CURRENT=0

run_step(){
  local idx="$1"; local key="$2"; local title="$3"; shift 3
  CURRENT=$((CURRENT+1))
  local step_key="STEP_${idx}_$(echo "$key" | tr 'a-z-' 'A-Z_')"
  local state
  state=$(progress_get "$step_key")
  state=${state:-pending}

  local desc=""
  case "$key" in
    01-system-check)
      desc=$'- Permisos root/sudo\n- SO Ubuntu 24.04\n- Internet, espacio, puertos, RAM'
      ;;
    02-install-deps)
      desc=$'- apt update\n- instalar herramientas base'
      ;;
    03-setup-db)
      desc=$'- MariaDB + pdns-backend-mysql\n- Crear BD y usuario\n- Importar esquema'
      ;;
    04-install-pdns-auth)
      desc=$'- Instalar pdns-server\n- Configurar MySQL\n- Puerto 5300'
      ;;
    05-install-pdns-recursor)
      desc=$'- Instalar pdns-recursor\n- Forwarders públicos\n- Integración con auth'
      ;;
    06-configure-zones)
      desc=$'- Crear zona inicial y registros'
      ;;
    07-install-pdns-admin)
      desc=$'- Python 3.12 con venv\n- PowerDNS-Admin backend y assets'
      ;;
    08-setup-nginx)
      desc=$'- Nginx reverse proxy con SSL'
      ;;
    09-setup-firewall)
      desc=$'- UFW reglas para DNS y Web UI'
      ;;
    10-generate-creds)
      desc=$'- Generar contraseñas y guardar CREDENTIALS.txt'
      ;;
    11-start-services)
      desc=$'- Habilitar y arrancar servicios'
      ;;
    12-final-tests)
      desc=$'- Tests de servicios y resolución DNS'
      ;;
  esac

  box_top "PASO ${CURRENT}/${TOTAL}: ${title}"
  echo "Estado actual: [ ${state^^} ]"
  echo
  echo -e "$desc"

  if [ "$RESUME" = true ] && [[ "$state" == completed* ]]; then
    log_info "Saltando ${key} (ya completado)"
    return 0
  fi

  if ! step_prompt "PASO ${CURRENT}/${TOTAL}: ${title}" "$state" "$desc"; then
    log_warn "Usuario canceló el paso ${key}"
    return 0
  fi

  local script="$ROOT_DIR/scripts/steps/${idx}-${key}.sh"
  if [ ! -f "$script" ]; then
    log_error "Script de paso no encontrado: $script (marcando como skipped)"
    progress_set "$step_key" "skipped"
    return 0
  fi

  # Ejecutar el paso: si no es ejecutable, invocamos con bash
  if [ ! -x "$script" ]; then
    log_warn "${script} no es ejecutable; invocando con bash"
    bash "$script" "$step_key" "$title"
  else
    "$script" "$step_key" "$title"
  fi
}

main(){
  local start_ts=$(date +%s)
  for s in "${STEPS[@]}"; do
    IFS=":" read -r idx key title <<< "$s"
    run_step "$idx" "$key" "$title"
  done
  local end_ts=$(date +%s)
  local elapsed=$((end_ts - start_ts))
  echo
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║           RESUMEN DE INSTALACIÓN                           ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  local done_count
  done_count=$(grep -c "=completed" "$PROGRESS_FILE" 2>/dev/null || echo 0)
  echo "Pasos completados: ${done_count}/${TOTAL}"
  echo "Tiempo total: ${elapsed}s"
  echo
  echo "📊 Log: ${LOG_FILE}"
  echo "📄 Credenciales (si se generaron): $ROOT_DIR/CREDENTIALS.txt"
}

main "$@"
