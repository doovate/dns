#!/usr/bin/env bash
# Configure nginx reverse proxy with self-signed SSL for PowerDNS-Admin
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_DIR="$BASE_DIR/configs"
# shellcheck disable=SC1090
source "$BASE_DIR/config.env"

log() { echo -e "\e[1;32m[NGINX]\e[0m $*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx openssl

mkdir -p /etc/nginx/ssl
if [[ ! -f /etc/nginx/ssl/pdns-admin.crt || ! -f /etc/nginx/ssl/pdns-admin.key ]]; then
  log "Generating self-signed certificate..."
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -subj "/CN=${DNS_SERVER_IP}" \
    -keyout /etc/nginx/ssl/pdns-admin.key \
    -out /etc/nginx/ssl/pdns-admin.crt
  chmod 600 /etc/nginx/ssl/pdns-admin.key
fi

# Render nginx config
NGINX_TPL="$CONF_DIR/nginx.conf.template"
NGINX_OUT="/etc/nginx/nginx.conf"
sed -e "s/{{WEBUI_PORT}}/${WEBUI_PORT}/g" "$NGINX_TPL" >"$NGINX_OUT"

systemctl enable --now nginx
systemctl restart nginx
log "nginx configured with SSL on port ${WEBUI_PORT}."
