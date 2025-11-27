#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 5: Instalación PowerDNS Recursor"

run_cmd apt-get install -y pdns-recursor || true

mkdir -p /etc/powerdns 2>/dev/null || true
if [ -f configs/recursor.conf.template ]; then
  export PDNS_RECURSOR_PORT DNS_FORWARDER_1 DNS_FORWARDER_2 DNS_SERVER_IP
  run_cmd envsubst < configs/recursor.conf.template > /etc/powerdns/recursor.conf
  run_cmd chmod 640 /etc/powerdns/recursor.conf
fi

run_cmd systemctl enable pdns-recursor || true
run_cmd systemctl restart pdns-recursor || true

log_success "PowerDNS Recursor instalado y configurado"
