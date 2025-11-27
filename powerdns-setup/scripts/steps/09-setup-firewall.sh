#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

main(){
  if [ "$ENABLE_FIREWALL" != true ]; then
    log_warn "Firewall deshabilitado por configuración (ENABLE_FIREWALL=false)"
    progress_set "$STEP_KEY" "skipped"
    return 0
  fi

  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y ufw"

  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw --force reset"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw default deny incoming"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw default allow outgoing"

  # SSH
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw allow ${SSH_PORT}/tcp"

  # DNS UDP desde redes internas
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw allow from ${INTERNAL_NETWORK} to any port ${PDNS_RECURSOR_PORT} proto udp"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw allow from ${VPN_NETWORK} to any port ${PDNS_RECURSOR_PORT} proto udp"

  # Web UI HTTPS desde redes internas
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw allow from ${INTERNAL_NETWORK} to any port ${NGINX_HTTPS_PORT} proto tcp"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw allow from ${VPN_NETWORK} to any port ${NGINX_HTTPS_PORT} proto tcp"

  run_or_recover "$STEP_TITLE" "$STEP_KEY" "ufw --force enable"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
