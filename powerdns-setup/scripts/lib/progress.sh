#!/bin/bash
# Progress handling, banner, step messages, summary
# Requires: colors.sh, logging.sh

PROGRESS_FILE=${PROGRESS_FILE:-.install_progress}
START_TIME_EPOCH=$(date +%s)

load_progress() {
  local resume=${1:-true}
  if [ "$resume" != "true" ]; then
    rm -f "$PROGRESS_FILE" 2>/dev/null || true
  fi
  touch "$PROGRESS_FILE"
}

is_step_completed() {
  local step_id="$1"
  grep -q "^COMPLETED:$step_id$" "$PROGRESS_FILE" 2>/dev/null
}

mark_step_completed() {
  local step_id="$1"
  if ! is_step_completed "$step_id"; then
    echo "COMPLETED:$step_id" >> "$PROGRESS_FILE"
  fi
}

mark_step_skipped() {
  local step_id="$1"
  if ! grep -q "^SKIPPED:$step_id$" "$PROGRESS_FILE" 2>/dev/null; then
    echo "SKIPPED:$step_id" >> "$PROGRESS_FILE"
  fi
}

show_banner() {
  echo ""
  color_title "╔════════════════════════════════════════════════════════════╗"
  color_title "║                 INSTALADOR DE POWERDNS                    ║"
  color_title "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

bar() {
  local current=$1 total=$2
  local width=24
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  printf '['
  printf '█%.0s' $(seq 1 $filled)
  printf '░%.0s' $(seq 1 $empty)
  printf ']'
}

update_progress_visual() {
  local current=$1 total=$2 label="$3"
  printf "\r"
  bar $current $total
  printf " %d%% (%d/%d) - %s..." $(( current*100/total )) $current $total "$label"
  echo "" > /dev/null # no-op to satisfy shells
}

show_step_info() {
  local name="$1"
  echo ""
  color_info "▶ $name"
}

show_step_success() {
  local name="$1"
  color_success "✓ $name"
}

show_step_error() {
  local name="$1"; local code="$2"
  color_error "✗ $name (código $code)"
}

show_step_skipped() {
  local name="$1"
  color_warn "⏭  Saltado: $name"
}

ask_continue() {
  read -r -p "¿Continuar con este paso? [S/n]: " choice
  case "$choice" in
    n|N) return 1 ;;
    *) return 0 ;;
  esac
}

show_summary() {
  local total="$1"
  echo ""
  color_title "╔════════════════════════════════════════════════════════════╗"
  color_title "║                 RESUMEN DE INSTALACIÓN                    ║"
  color_title "╚════════════════════════════════════════════════════════════╝"
  echo ""
  local completed skipped
  completed=$(grep -c '^COMPLETED:' "$PROGRESS_FILE" 2>/dev/null || echo 0)
  skipped=$(grep -c '^SKIPPED:' "$PROGRESS_FILE" 2>/dev/null || echo 0)
  local end=$(date +%s)
  local duration=$(( end - START_TIME_EPOCH ))
  printf "Pasos completados: %d/%d\n" "$completed" "$total"
  if [ "$skipped" -gt 0 ]; then
    printf "Pasos saltados: %d\n" "$skipped"
  fi
  echo ""
  # List steps
  for step in "${STEPS[@]}"; do
    local id="${step%%:*}"; local title="${step#*:}"
    if grep -q "^COMPLETED:$id$" "$PROGRESS_FILE" 2>/dev/null; then
      echo "✓ PASO ${id%%-*}: $title"
    elif grep -q "^SKIPPED:$id$" "$PROGRESS_FILE" 2>/dev/null; then
      echo "⏭ PASO ${id%%-*}: $title"
    else
      echo "✗ PASO ${id%%-*}: $title"
    fi
  done
  echo ""
  printf "Tiempo total: %dm %02ds\n" $((duration/60)) $((duration%60))
  echo ""
  echo "🌐 Acceso a PowerDNS-Admin:"
  echo "   URL: https://$DNS_SERVER_IP:$WEBUI_PORT"
  echo "   Usuario: $ADMIN_USERNAME"
  echo "   Contraseña: [ver CREDENTIALS.txt]"
  echo ""
  echo "📄 Credenciales: $INSTALL_DIR/CREDENTIALS.txt"
  echo "📊 Log de instalación: $LOG_PATH"
}
