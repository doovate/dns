#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 8: Configuración de nginx"

# Create self-signed cert if not exists
if [ ! -f /etc/nginx/pdns-admin.crt ] || [ ! -f /etc/nginx/pdns-admin.key ]; then
  log_info "Generando certificado SSL autofirmado"
  run_cmd openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/pdns-admin.key -out /etc/nginx/pdns-admin.crt \
    -subj "/CN=$DNS_SERVER_IP"
  run_cmd chmod 600 /etc/nginx/pdns-admin.key
fi

# Install nginx site configuration
export WEBUI_PORT DNS_SERVER_IP
run_cmd envsubst < configs/nginx.conf.template > /etc/nginx/sites-available/pdns-admin.conf

if [ ! -L /etc/nginx/sites-enabled/pdns-admin.conf ]; then
  run_cmd ln -s /etc/nginx/sites-available/pdns-admin.conf /etc/nginx/sites-enabled/pdns-admin.conf
fi

# Disable default site if present
if [ -L /etc/nginx/sites-enabled/default ]; then
  run_cmd rm -f /etc/nginx/sites-enabled/default
fi

run_cmd nginx -t
run_cmd systemctl enable nginx
run_cmd systemctl restart nginx

log_success "nginx configurado"
