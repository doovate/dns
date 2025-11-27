#!/usr/bin/env bash
# Centralized error handling for steps with interactive options

show_error_suggestions() {
  local step="$1"; local code="$2"
  echo "Posibles causas y sugerencias para $step (código $code):"
  case "$step" in
    02-install-deps)
      echo "- Ejecuta 'apt update' y revisa conectividad.";
      echo "- Verifica mirrors de Ubuntu.";
      ;;
    03-setup-db)
      echo "- Verifica que el servicio de base de datos esté activo.";
      echo "- Revisa credenciales en config.env.";
      ;;
    04-install-pdns-auth)
      echo "- Revisa /etc/powerdns/pdns.conf y la cadena de conexión.";
      echo "- Consulta 'journalctl -xeu pdns.service'.";
      ;;
    05-install-pdns-recursor)
      echo "- Revisa /etc/powerdns/recursor.conf y puertos libres.";
      ;;
    07-install-pdns-admin)
      echo "- Revisa dependencias de Python y logs de gunicorn.";
      ;;
    08-setup-nginx)
      echo "- Valida sintaxis: 'nginx -t' y certificados SSL.";
      ;;
    09-setup-firewall)
      echo "- Comprueba que UFW esté instalado y habilitado.";
      ;;
    11-start-services)
      echo "- Verifica estado con scripts/healthcheck.sh.";
      ;;
    *)
      echo "- Revisa el log de instalación y el estado del servicio relacionado.";
      ;;
  esac
}

show_full_log() {
  if [[ -f "$LOG_FILE" ]]; then
    tail -n 200 "$LOG_FILE"
  else
    echo "No hay log disponible en $LOG_FILE"
  fi
}

retry_step() {
  local step="$1"
  echo "Reintentando $step..."
  bash "scripts/steps/${step}.sh" && mark_step_completed "$step" || mark_step_failed "$step" "retry_failed"
}

skip_step() {
  local step="$1"
  echo "Marcando $step como saltado. Puedes retomarlo ejecutando --resume."
  mark_step_pending "$step"
}

abort_installation() {
  echo "Instalación abortada por el usuario."
  exit 1
}

handle_error() {
  local step="$1"; local exit_code="$2"
  echo ""
  echo "❌ ERROR EN EL PASO: $step"
  echo "Código de salida: $exit_code"
  echo ""
  echo "Log completo disponible en: $LOG_FILE"
  echo ""
  show_error_suggestions "$step" "$exit_code"
  echo ""

  if [[ "${INTERACTIVE_MODE:-true}" != true ]]; then
    echo "Modo no interactivo: abortando."
    exit "$exit_code"
  fi

  while true; do
    echo "¿Qué deseas hacer?"
    echo "  [R] Reintentar este paso"
    echo "  [S] Saltar este paso (no recomendado)"
    echo "  [L] Ver log completo"
    echo "  [A] Abortar instalación"
    read -r -p "Opción [R/s/l/a]: " choice || true
    case "$choice" in
      r|R|"") retry_step "$step"; return ;;
      s|S) skip_step "$step"; return ;;
      l|L) show_full_log ;;
      a|A) abort_installation ;;
      *) echo "Opción no válida" ;;
    esac
  done
}
