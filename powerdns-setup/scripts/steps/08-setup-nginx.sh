#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

render_template(){
  local tpl="$1"; shift
  local out="$1"; shift
  local content
  content=$(cat "$tpl")
  content=${content//\{\{NGINX_HTTPS_PORT\}\}/$NGINX_HTTPS_PORT}
  content=${content//\{\{DNS_SERVER_IP\}\}/$DNS_SERVER_IP}
  content=${content//\{\{GUNICORN_PORT\}\}/$GUNICORN_PORT}
  content=${content//\{\{PDNS_ADMIN_PATH\}\}/$PDNS_ADMIN_PATH}
  echo "$content" > "$out"
}

main(){
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y nginx openssl"

  mkdir -p /etc/nginx/ssl
  if [ "$SSL_TYPE" = "selfsigned" ] && [ ! -f /etc/nginx/ssl/powerdns.crt ]; then
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/powerdns.key -out /etc/nginx/ssl/powerdns.crt -subj '/C=ES/ST=Madrid/L=Madrid/O=Doovate/CN=${DNS_SERVER_IP}'"
  fi

  render_template "$ROOT_DIR/configs/nginx-powerdns.conf.template" /etc/nginx/sites-available/powerdns-admin

  if [ ! -e /etc/nginx/sites-enabled/powerdns-admin ]; then
    ln -s /etc/nginx/sites-available/powerdns-admin /etc/nginx/sites-enabled/
  fi
  rm -f /etc/nginx/sites-enabled/default || true

  run_or_recover "$STEP_TITLE" "$STEP_KEY" "nginx -t"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl restart nginx"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable nginx"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
