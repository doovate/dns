#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 9: Configuración de firewall (ufw)"

if ! command -v ufw >/dev/null 2>&1; then
  run_cmd apt-get install -y ufw
fi

# Default policies
run_cmd ufw default deny incoming
run_cmd ufw default allow outgoing

# Allow SSH to avoid lockout
if ss -lnt | awk '{print $4}' | grep -q ":22$"; then
  run_cmd ufw allow 22/tcp
fi

# Helper to allow from network
allow_from_net() {
  local net="$1"; shift
  local rule="$*"
  [ -z "$net" ] && return 0
  run_cmd ufw allow from "$net" to any $rule
}

# DNS (53 tcp/udp) only from internal networks
allow_from_net "$INTERNAL_NETWORK" port 53 proto tcp
allow_from_net "$INTERNAL_NETWORK" port 53 proto udp
allow_from_net "$VPN_NETWORK" port 53 proto tcp
allow_from_net "$VPN_NETWORK" port 53 proto udp

# Web UI (WEBUI_PORT) only from internal networks
allow_from_net "$INTERNAL_NETWORK" port $WEBUI_PORT proto tcp
allow_from_net "$VPN_NETWORK" port $WEBUI_PORT proto tcp

# Enable ufw if not enabled
if ufw status | grep -q "Status: inactive"; then
  echo "y" | run_cmd ufw enable
else
  log_info "ufw ya estaba habilitado"
fi

run_cmd ufw status verbose

log_success "Firewall configurado"
