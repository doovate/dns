#!/bin/bash
# Error handling and recovery options
# Requires: colors.sh, logging.sh, progress.sh

retry_step() {
  local step_id="$1"; local step_script="$2"; local step_name="$3"
  log_info "Reintentando paso $step_id - $step_name"
  if bash "$step_script"; then
    mark_step_completed "$step_id"
    show_step_success "$step_name"
  else
    local code=$?
    show_step_error "$step_name" "$code"
    handle_error "$step_id" "$code" "$step_name" "$step_script"
  fi
}

skip_step() {
  local step_id="$1"; local step_name="$2"
  log_warn "Saltando paso $step_id - $step_name por solicitud del usuario"
  mark_step_skipped "$step_id"
  show_step_skipped "$step_name"
}

abort_installation() {
  echo ""
  color_error "Instalación abortada por el usuario."
  exit 1
}

show_error_suggestions() {
  local step_id="$1"; local exit_code="$2"
  case "$step_id" in
    03-setup-db)
      echo "- Verifique la conectividad a la base de datos y los permisos del usuario."
      ;;
    04-install-pdns-auth|05-install-pdns-recursor)
      echo "- Revise los repositorios y la conectividad a Internet (apt update)."
      ;;
    08-setup-nginx)
      echo "- Verifique puertos en uso y permisos de certificados."
      ;;
    09-setup-firewall)
      echo "- Asegúrese de no bloquear su propio acceso SSH."
      ;;
    *)
      echo "- Consulte el log para más detalles."
      ;;
  esac
}

handle_error() {
  local step_id="$1"; local exit_code="$2"; local step_name="$3"; local step_script="$4"
  echo ""
  echo "❌ ERROR EN EL PASO: $step_id - $step_name"
  echo "Código de salida: $exit_code"
  echo ""
  echo "Log completo disponible en: $LOG_PATH"
  echo ""
  show_error_suggestions "$step_id" "$exit_code"
  echo ""
  echo "¿Qué deseas hacer?"
  echo "  [R] Reintentar este paso"
  echo "  [S] Saltar este paso (no recomendado)"
  echo "  [L] Ver log completo"
  echo "  [A] Abortar instalación"
  echo ""
  read -r -p "Opción [R/s/l/a]: " choice
  case $choice in
    r|R|"") retry_step "$step_id" "$step_script" "$step_name" ;;
    s|S) skip_step "$step_id" "$step_name" ;;
    l|L) show_full_log; handle_error "$step_id" "$exit_code" "$step_name" "$step_script" ;;
    a|A) abort_installation ;;
    *) retry_step "$step_id" "$step_script" "$step_name" ;;
  esac
}
