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
  content=${content//\{\{PDNS_AUTH_PORT\}\}/$PDNS_AUTH_PORT}
  content=${content//\{\{DNS_SERVER_IP\}\}/$DNS_SERVER_IP}
  content=${content//\{\{DB_HOST\}\}/$DB_HOST}
  content=${content//\{\{DB_PORT\}\}/$DB_PORT}
  content=${content//\{\{DB_NAME\}\}/$DB_NAME}
  content=${content//\{\{DB_USER\}\}/$DB_USER}
  content=${content//\{\{DB_PASSWORD\}\}/$DB_PASSWORD}
  echo "$content" > "$out"
}

main(){
  # Deshabilitar systemd-resolved y fijar resolv temporal para evitar conflictos
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl disable systemd-resolved || true"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl stop systemd-resolved || true"
  if [ -f /etc/resolv.conf ]; then
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "chattr -i /etc/resolv.conf || true"
  fi
  echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf || true

  # Instalar PowerDNS Authoritative
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y pdns-server"

  # Configurar archivos
  mkdir -p /etc/powerdns/pdns.d
  render_template "$ROOT_DIR/configs/pdns.local.gmysql.conf.template" \
                  "/etc/powerdns/pdns.d/pdns.local.gmysql.conf"
  # Asegurar puerto y dirección
  if ! grep -q "^local-port=" /etc/powerdns/pdns.conf 2>/dev/null; then
    echo "local-port=${PDNS_AUTH_PORT}" >> /etc/powerdns/pdns.conf
  else
    sed -i "s/^local-port=.*/local-port=${PDNS_AUTH_PORT}/" /etc/powerdns/pdns.conf
  fi
  if ! grep -q "^local-address=" /etc/powerdns/pdns.conf 2>/dev/null; then
    echo "local-address=${DNS_SERVER_IP}" >> /etc/powerdns/pdns.conf
  else
    sed -i "s/^local-address=.*/local-address=${DNS_SERVER_IP}/" /etc/powerdns/pdns.conf
  fi

  # Reiniciar servicio
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl restart pdns"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable pdns"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
