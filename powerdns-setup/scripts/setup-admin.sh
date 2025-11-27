#!/usr/bin/env bash
# Install and configure PowerDNS-Admin (venv + gunicorn + systemd)
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$BASE_DIR/config.env"

log() { echo -e "\e[1;32m[ADMIN]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

PDNSA_DIR=/opt/powerdns-admin
PDNSA_VENV=$PDNSA_DIR/venv
PDNSA_USER=pdnsadmin
PDNSA_PORT=9190

install_reqs() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y git python3-venv python3-pip python3-dev build-essential libpq-dev
}

setup_app() {
  id -u "$PDNSA_USER" &>/dev/null || useradd --system --home "$PDNSA_DIR" --shell /usr/sbin/nologin "$PDNSA_USER"
  if [[ ! -d "$PDNSA_DIR" ]]; then
    git clone https://github.com/PowerDNS-Admin/PowerDNS-Admin.git "$PDNSA_DIR"
  fi
  python3 -m venv "$PDNSA_VENV"
  source "$PDNSA_VENV/bin/activate"
  pip install --upgrade pip wheel
  pip install -r "$PDNSA_DIR/requirements.txt"

  cat >"$PDNSA_DIR/config.py" <<PY
SQLA_DB_USER = '${DB_USER}'
SQLA_DB_PASSWORD = '${DB_PASSWORD}'
SQLA_DB_HOST = '127.0.0.1'
SQLA_DB_NAME = '${DB_NAME}'
SQLALCHEMY_DATABASE_URI = 'postgresql://${DB_USER}:${DB_PASSWORD}@127.0.0.1/${DB_NAME}'
SECRET_KEY = '${PDNS_ADMIN_SECRET_KEY}'
BIND_ADDRESS = '127.0.0.1'
PORT = ${PDNSA_PORT}
SALT = '${PDNS_ADMIN_SECRET_KEY}'
PDNS_API_URL = 'http://127.0.0.1:8081'
PDNS_API_KEY = '${PDNS_API_KEY}'
SITENAME = 'PowerDNS-Admin'
SESSION_COOKIE_SAMESITE = 'Lax'
PY

  pushd "$PDNSA_DIR" >/dev/null
  source "$PDNSA_VENV/bin/activate"
  FLASK_APP=powerdnsadmin/__init__.py FLASK_CONFIG=production "$PDNSA_VENV/bin/flask" db upgrade || true
  popd >/dev/null

  chown -R "$PDNSA_USER":"$PDNSA_USER" "$PDNSA_DIR"
}

create_admin_user() {
  source "$PDNSA_VENV/bin/activate"
  python3 - "$ADMIN_USERNAME" "$ADMIN_PASSWORD" "$ADMIN_EMAIL" <<'PY'
import os
import sys
from powerdnsadmin import create_app
from powerdnsadmin.models.user import User

username, password, email = sys.argv[1:4]
app = create_app()
with app.app_context():
    u = User.query.filter_by(username=username).first()
    if not u:
        u = User(username=username, plain_text_password=password, email=email)
        u.role_id = 1
        u.confirmed = True
        u.create_user()
        print("[ADMIN] Admin user created")
    else:
        print("[ADMIN] Admin user already exists")
PY
}

systemd_units() {
  cat >/etc/systemd/system/powerdns-admin.service <<UNIT
[Unit]
Description=PowerDNS-Admin Gunicorn
After=network.target

[Service]
Type=simple
User=$PDNSA_USER
Group=$PDNSA_USER
WorkingDirectory=$PDNSA_DIR
Environment="FLASK_APP=powerdnsadmin/__init__.py" "FLASK_CONFIG=production"
ExecStart=$PDNSA_VENV/bin/gunicorn -b 127.0.0.1:${PDNSA_PORT} 'powerdnsadmin:create_app()'
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now powerdns-admin.service
}

main() {
  install_reqs
  setup_app
  create_admin_user
  systemd_units
  log "PowerDNS-Admin installed and started."
}

main "$@"
