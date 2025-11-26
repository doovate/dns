#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env
require_root

info "Instalando PowerDNS-Admin"

apt_install git python3-venv python3-dev build-essential libpq-dev pkg-config

# Create app directories
install -d -o root -g root "$PDNSA_BASE_DIR" "$PDNSA_LOG_DIR" /etc/nginx/ssl

# Fetch or update PowerDNS-Admin
if [[ ! -d "$PDNSA_BASE_DIR/.git" ]]; then
  git clone --depth=1 https://github.com/PowerDNS-Admin/PowerDNS-Admin.git "$PDNSA_BASE_DIR"
else
  (cd "$PDNSA_BASE_DIR" && git pull --rebase --autostash || true)
fi

# Python venv and dependencies
python3 -m venv "$PDNSA_VENV_DIR" || true
source "$PDNSA_VENV_DIR/bin/activate"
pip install --upgrade pip wheel
pip install -r "$PDNSA_BASE_DIR/requirements.txt"
# DB drivers
if [[ "$DB_ENGINE" == "POSTGRES" ]]; then
  pip install psycopg2-binary
  SQLALCHEMY_URI="postgresql://${PDNSADMIN_DB_USER}:${PDNSADMIN_DB_PASS}@${PG_HOST}:${PG_PORT}/${PDNSADMIN_DB_NAME}"
else
  error "Solo PostgreSQL soportado en esta versión"; exit 1
fi

# Generate config.py for PowerDNS-Admin
PDA_CFG="$PDNSA_BASE_DIR/config.py"
if [[ ! -f "$PDA_CFG" ]]; then
  SECRET=$(openssl rand -hex 32)
  cat > "$PDA_CFG" <<CFG
import os
basedir = os.path.abspath(os.path.dirname(__file__))

SECRET_KEY = "${SECRET}"
BIND_ADDRESS = "127.0.0.1"
PORT = int(os.environ.get("PORT", ${PDNSA_HTTP_PORT}))
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_DATABASE_URI = "${SQLALCHEMY_URI}"
LOG_LEVEL = "INFO"

PDNS_STATS_URL = "http://127.0.0.1:${PDNS_API_PORT}/"
PDNS_API_KEY = "${PDNS_API_KEY}"
PDNS_VERSION = "4.8.0"
SALT = SECRET_KEY
SESSION_COOKIE_HTTPONLY = True
CSRF_ENABLED = True
BASIC_ENABLED = True

# Initial admin account
ADMIN_USERNAME = "${PDNSA_ADMIN_USER}"
ADMIN_PASSWORD = "${PDNSA_ADMIN_PASSWORD}"
ADMIN_EMAIL = "${PDNSA_ADMIN_EMAIL}"
CFG
fi

# Initialize DB schema for PowerDNS-Admin
export FLASK_APP=powerdnsadmin/__init__.py
(cd "$PDNSA_BASE_DIR" && FLASK_APP=powerdnsadmin/__init__.py "$PDNSA_VENV_DIR/bin/flask" db upgrade || true)

# Create systemd service
install -d -m 755 /etc/systemd/system
cat > /etc/systemd/system/powerdns-admin.service <<UNIT
[Unit]
Description=PowerDNS-Admin Gunicorn Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/powerdns-admin
Environment="PATH=/opt/powerdns-admin/venv/bin"
ExecStart=/opt/powerdns-admin/venv/bin/gunicorn -b 127.0.0.1:${PDNSA_HTTP_PORT} --workers 3 "powerdnsadmin:create_app()"
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

# Make sure www-data can write logs
chown -R www-data:www-data "$PDNSA_LOG_DIR"

# SSL cert
if [[ "$ENABLE_LETSENCRYPT" == "true" ]]; then
  apt_install certbot python3-certbot-nginx
  certbot --nginx -d "$PDNSA_FQDN" --non-interactive --agree-tos -m "$PDNSA_ADMIN_EMAIL" || warn "No se pudo emitir Let's Encrypt, usando autofirmado"
fi
if [[ ! -f "/etc/nginx/ssl/${PDNSA_FQDN}.crt" || ! -f "/etc/nginx/ssl/${PDNSA_FQDN}.key" ]]; then
  info "Generando certificado autofirmado"
  openssl req -x509 -newkey rsa:4096 -sha256 -days 825 -nodes \
    -keyout "/etc/nginx/ssl/${PDNSA_FQDN}.key" \
    -out "/etc/nginx/ssl/${PDNSA_FQDN}.crt" \
    -subj "/C=${SELF_SIGNED_COUNTRY}/ST=${SELF_SIGNED_STATE}/L=${SELF_SIGNED_LOCALITY}/O=${SELF_SIGNED_ORG}/OU=${SELF_SIGNED_OU}/CN=${PDNSA_FQDN}" || true
fi

# Nginx config
render_template "$ROOT_DIR/configs/nginx-pdns-admin.conf.template" /etc/nginx/sites-available/pdns-admin.conf
ln -sf /etc/nginx/sites-available/pdns-admin.conf /etc/nginx/sites-enabled/pdns-admin.conf
if [[ -f /etc/nginx/sites-enabled/default ]]; then rm -f /etc/nginx/sites-enabled/default; fi
nginx -t
systemctl reload nginx || systemctl restart nginx || true

# Enable and start service
systemctl daemon-reload
systemctl enable --now powerdns-admin.service

success "PowerDNS-Admin desplegado en https://${PDNSA_FQDN}"
