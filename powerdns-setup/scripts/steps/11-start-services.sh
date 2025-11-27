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
  # Crear servicio systemd para PowerDNS-Admin
  local unit=/etc/systemd/system/powerdns-admin.service
  if [ ! -f "$unit" ]; then
    cat > "$unit" <<EOF
[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=${PDNS_ADMIN_PATH}
ExecStart=${PDNS_ADMIN_PATH}/flask/bin/gunicorn -w 4 -b 127.0.0.1:${GUNICORN_PORT} "powerdnsadmin:create_app()"
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  fi

  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl daemon-reload"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable powerdns-admin"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl restart powerdns-admin"

  # Asegurar servicios principales
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable pdns"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl restart pdns"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable pdns-recursor"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl restart pdns-recursor"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
