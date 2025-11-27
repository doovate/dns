#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 7: Instalación PowerDNS-Admin"

APP_DIR=/opt/powerdns-admin
run_cmd mkdir -p "$APP_DIR"

if [ -d "$APP_DIR/.git" ]; then
  log_info "PowerDNS-Admin ya clonado en $APP_DIR"
else
  run_cmd git clone https://github.com/PowerDNS-Admin/PowerDNS-Admin.git "$APP_DIR"
fi

# Python venv
if [ -d "$APP_DIR/.venv" ]; then
  log_info "Entorno virtual ya existe"
else
  run_cmd python3 -m venv "$APP_DIR/.venv"
fi

run_cmd bash -c ". '$APP_DIR/.venv/bin/activate' && pip install --upgrade pip && pip install -r '$APP_DIR/requirements.txt'"

# Configure .env
if [ ! -f "$APP_DIR/.env" ]; then
  SECRET_KEY=$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)
  export SECRET_KEY PDNS_API_KEY DB_TYPE DB_NAME DB_USER DB_PASSWORD DNS_SERVER_IP PDNS_AUTH_PORT
  cat > "$APP_DIR/.env" <<ENV
SECRET_KEY=$SECRET_KEY
BIND_ADDRESS=127.0.0.1
PORT=9192
SQLA_DB_USER=$DB_USER
SQLA_DB_PASSWORD=$DB_PASSWORD
SQLA_DB_HOST=${DB_HOST:-127.0.0.1}
SQLA_DB_NAME=$DB_NAME
SQLA_DB_PORT=${DB_PORT:-}
SQLA_DB_TYPE=$DB_TYPE
PDNS_API_URL=http://127.0.0.1:8081
PDNS_API_KEY=${PDNS_API_KEY:-changeme}
ENV
  run_cmd chown root:root "$APP_DIR/.env"
  run_cmd chmod 600 "$APP_DIR/.env"
fi

# Initialize DB for PDA
run_cmd bash -c ". '$APP_DIR/.venv/bin/activate' && cd '$APP_DIR' && export FLASK_APP=powerdnsadmin/__init__.py && flask db upgrade"

# Create admin user if not present
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  ADMIN_PASSWORD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9!@#%^&*()_+=' | head -c 24)
fi
ADMIN_EXISTS=$(bash -c ". '$APP_DIR/.venv/bin/activate' && cd '$APP_DIR' && python - <<'PY'
from powerdnsadmin.models.user import User
from powerdnsadmin import create_app
app = create_app()
ctx = app.app_context(); ctx.push()
print('1' if User.query.filter_by(username='$ADMIN_USERNAME').first() else '0')
PY")
if [ "$ADMIN_EXISTS" != "1" ]; then
  log_info "Creando usuario admin en PowerDNS-Admin"
  run_cmd bash -c ". '$APP_DIR/.venv/bin/activate' && cd '$APP_DIR' && python - <<'PY'
from powerdnsadmin.models.user import User
from powerdnsadmin import create_app, db
app = create_app(); app.app_context().push()
u=User(username='$ADMIN_USERNAME', password='$ADMIN_PASSWORD', role_name='Administrator', email='$ADMIN_EMAIL', created_by='installer')
db.session.add(u); db.session.commit(); print('OK')
PY"
fi

# Systemd service
SERVICE_FILE=/etc/systemd/system/powerdns-admin.service
cat > /tmp/powerdns-admin.service <<UNIT
[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
Environment="FLASK_APP=powerdnsadmin/__init__.py"
ExecStart=$APP_DIR/.venv/bin/flask run --host=127.0.0.1 --port=9192
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
run_cmd cp /tmp/powerdns-admin.service "$SERVICE_FILE"
run_cmd systemctl daemon-reload
run_cmd systemctl enable powerdns-admin
run_cmd systemctl restart powerdns-admin || true

# Append credentials
{
  echo "";
  echo "[PowerDNS-Admin]";
  echo "URL: https://$DNS_SERVER_IP:$WEBUI_PORT";
  echo "Usuario: $ADMIN_USERNAME";
  echo "Contraseña: $ADMIN_PASSWORD";
} >> "$INSTALL_DIR/CREDENTIALS.txt"
run_cmd chmod 600 "$INSTALL_DIR/CREDENTIALS.txt"

log_success "PowerDNS-Admin instalado y configurado"
