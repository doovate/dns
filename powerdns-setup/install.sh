#!/usr/bin/env bash
# Automated installer for a professional PowerDNS stack on Ubuntu 24.04 LTS
# Components: PowerDNS Authoritative, PowerDNS Recursor, PostgreSQL, PowerDNS-Admin, Nginx (SSL), UFW
# Usage: sudo bash install.sh

set -euo pipefail

REPO_ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
CREDENTIALS_FILE="$REPO_ROOT_DIR/CREDENTIALS.txt"

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "[ERROR] This installer must be run as root. Use: sudo bash install.sh" >&2
    exit 1
  fi
}

log() { echo -e "\e[1;32m[+]\e[0m $*"; }
info() { echo -e "\e[1;34m[i]\e[0m $*"; }
warn() { echo -e "\e[1;33m[!]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

ensure_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    err "Missing $CONFIG_FILE. Please create it before running."
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  set +a
}

rand_hex() { openssl rand -hex 24; }
rand_pw() { openssl rand -base64 24 | tr -d '\n' | tr '/+' 'Aa'; }

# Defaults and derived values
set_defaults() {
  DB_TYPE=${DB_TYPE:-postgresql}
  DB_NAME=${DB_NAME:-powerdns}
  DB_USER=${DB_USER:-pdns}
  DB_PASSWORD=${DB_PASSWORD:-}
  ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
  ADMIN_PASSWORD=${ADMIN_PASSWORD:-}
  ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$DNS_ZONE}
  PDNS_AUTH_PORT=${PDNS_AUTH_PORT:-5300}
  PDNS_RECURSOR_PORT=${PDNS_RECURSOR_PORT:-53}
  WEBUI_PORT=${WEBUI_PORT:-9191}

  # Generated secrets
  if [[ -z "${DB_PASSWORD}" ]]; then DB_PASSWORD=$(rand_pw); fi
  PDNS_API_KEY=${PDNS_API_KEY:-$(rand_hex)}
  PDNS_ADMIN_SECRET_KEY=${PDNS_ADMIN_SECRET_KEY:-$(rand_hex)}
  PDNS_ADMIN_API_KEY=${PDNS_ADMIN_API_KEY:-$(rand_hex)}
  if [[ -z "${ADMIN_PASSWORD}" ]]; then ADMIN_PASSWORD=$(rand_pw); fi

  # Other derived
  PDNS_API_URL="http://127.0.0.1:8081" # pdns authoritative API default
  SITE_FQDN="dns.$DNS_ZONE"
}

apt_install_packages() {
  log "Updating apt and installing required packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    gnupg2 lsb-release ca-certificates software-properties-common curl jq \
    postgresql postgresql-contrib \
    pdns-server pdns-backend-pgsql pdns-recursor \
    nginx openssl \
    git python3-venv python3-pip python3-dev build-essential \
    ufw
}

setup_postgres() {
  log "Configuring PostgreSQL for PowerDNS and PowerDNS-Admin"
  # Create DB and user for PDNS
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';"
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"

  # Apply PDNS schema
  if ! sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='domains'" | grep -q 1; then
    info "Applying PowerDNS authoritative schema"
    cat <<'SQL' | sudo -u postgres psql -d "$DB_NAME"
CREATE TABLE IF NOT EXISTS domains (
  id              SERIAL PRIMARY KEY,
  name            VARCHAR(255) NOT NULL,
  master          VARCHAR(128) DEFAULT NULL,
  last_check      INT DEFAULT NULL,
  type            VARCHAR(6) NOT NULL,
  notified_serial INT DEFAULT NULL,
  account         VARCHAR(40) DEFAULT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS name_index ON domains(name);

CREATE TABLE IF NOT EXISTS records (
  id              SERIAL PRIMARY KEY,
  domain_id       INT DEFAULT NULL,
  name            VARCHAR(255) DEFAULT NULL,
  type            VARCHAR(10) DEFAULT NULL,
  content         VARCHAR(65535) DEFAULT NULL,
  ttl             INT DEFAULT NULL,
  prio            INT DEFAULT NULL,
  change_date     INT DEFAULT NULL,
  disabled        BOOLEAN DEFAULT 'f',
  ordername       VARCHAR(255) DEFAULT NULL,
  auth            BOOLEAN DEFAULT 't'
);
CREATE INDEX IF NOT EXISTS rec_name_index ON records(name);
CREATE INDEX IF NOT EXISTS rec_type_index ON records(type);
CREATE INDEX IF NOT EXISTS domain_id ON records(domain_id);

CREATE TABLE IF NOT EXISTS supermasters (
  ip        INET NOT NULL,
  nameserver VARCHAR(255) NOT NULL,
  account   VARCHAR(40) NOT NULL
);

CREATE TABLE IF NOT EXISTS comments (
  id          SERIAL PRIMARY KEY,
  domain_id   INT NOT NULL,
  name        VARCHAR(255) NOT NULL,
  type        VARCHAR(10) NOT NULL,
  modified_at INT NOT NULL,
  account     VARCHAR(40) NOT NULL,
  comment     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS comments_domain_id_idx ON comments (domain_id);
CREATE INDEX IF NOT EXISTS comments_name_type_idx ON comments (name, type);
CREATE INDEX IF NOT EXISTS comments_order_idx ON comments (domain_id, modified_at);

CREATE TABLE IF NOT EXISTS domainmetadata (
  id         SERIAL PRIMARY KEY,
  domain_id  INT REFERENCES domains(id) ON DELETE CASCADE,
  kind       VARCHAR(32),
  content    TEXT
);
CREATE INDEX IF NOT EXISTS domainmetadata_idx ON domainmetadata(domain_id, kind);

CREATE TABLE IF NOT EXISTS cryptokeys (
  id         SERIAL PRIMARY KEY,
  domain_id  INT REFERENCES domains(id) ON DELETE CASCADE,
  flags      INT NOT NULL,
  active     BOOLEAN,
  content    TEXT
);
CREATE INDEX IF NOT EXISTS domainidindex ON cryptokeys(domain_id);

CREATE TABLE IF NOT EXISTS tsigkeys (
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(255),
  algorithm VARCHAR(50),
  secret    VARCHAR(255)
);
CREATE UNIQUE INDEX IF NOT EXISTS namealgoindex ON tsigkeys(name, algorithm);
SQL
  fi

  # Separate DB for PowerDNS-Admin
  PDA_DB_NAME=${PDA_DB_NAME:-powerdns_admin}
  PDA_DB_USER=${PDA_DB_USER:-pdnsadmin}
  PDA_DB_PASSWORD=${PDA_DB_PASSWORD:-$(rand_pw)}
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PDA_DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE $PDA_DB_USER WITH LOGIN PASSWORD '$PDA_DB_PASSWORD';"
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$PDA_DB_NAME'" | grep -q 1 || \
    sudo -u postgres createdb -O "$PDA_DB_USER" "$PDA_DB_NAME"
}

configure_pdns_authoritative() {
  log "Configuring PowerDNS Authoritative"
  mkdir -p /etc/powerdns
  cat > /etc/powerdns/pdns.conf <<EOF
config-dir=/etc/powerdns
setuid=pdns
setgid=pdns
version-string=powerdns

# Listen on localhost for API and on $PDNS_AUTH_PORT for auth service
local-address=0.0.0.0
local-port=$PDNS_AUTH_PORT

launch=gpgsql
# PostgreSQL DSN
gpgsql-host=127.0.0.1
gpgsql-port=5432
gpgsql-dbname=$DB_NAME
gpgsql-user=$DB_USER
gpgsql-password=$DB_PASSWORD

api=yes
api-key=$PDNS_API_KEY
webserver=yes
webserver-address=127.0.0.1
webserver-port=8081

# Security
allow-dnsupdate-from=$INTERNAL_NETWORK,$VPN_NETWORK,127.0.0.1
EOF

  systemctl enable pdns
  systemctl restart pdns
}

configure_pdns_recursor() {
  log "Configuring PowerDNS Recursor"
  mkdir -p /etc/powerdns
  cat > /etc/powerdns/recursor.conf <<EOF
# Recursor listens on the main DNS IP and forwards internal zone to auth
local-address=$DNS_SERVER_IP
local-port=$PDNS_RECURSOR_PORT

# allow internal and VPN clients
allow-from=$INTERNAL_NETWORK,$VPN_NETWORK,127.0.0.1

# Forward internal authoritative zones to PDNS auth
forward-zones=$DNS_ZONE=127.0.0.1:$PDNS_AUTH_PORT

# Public resolvers for everything else
forward-zones-recurse=.=$DNS_FORWARDER_1;$DNS_FORWARDER_2

quiet=yes
EOF
  systemctl enable pdns-recursor
  systemctl restart pdns-recursor
}

install_powerdns_admin() {
  log "Installing PowerDNS-Admin (from GitHub)"
  PDA_DIR=/opt/powerdns-admin
  if [[ ! -d "$PDA_DIR" ]]; then
    git clone https://github.com/PowerDNS-Admin/PowerDNS-Admin.git "$PDA_DIR"
  fi
  cd "$PDA_DIR"
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip wheel
  pip install -r requirements.txt

  # Create config.py
  cat > $PDA_DIR/config.py <<EOF
import os
basedir = os.path.abspath(os.path.dirname(__file__))

SQLA_DB_USER = "$PDA_DB_USER"
SQLA_DB_PASSWORD = "$PDA_DB_PASSWORD"
SQLA_DB_NAME = "$PDA_DB_NAME"
SQLA_DB_HOST = "127.0.0.1"
SQLA_DB_PORT = 5432

SQLALCHEMY_DATABASE_URI = f"postgresql://{SQLA_DB_USER}:{SQLA_DB_PASSWORD}@{SQLA_DB_HOST}:{SQLA_DB_PORT}/{SQLA_DB_NAME}"
SQLALCHEMY_TRACK_MODIFICATIONS = False

SECRET_KEY = "$PDNS_ADMIN_SECRET_KEY"
BIND_ADDRESS = "127.0.0.1"
PORT = $WEBUI_PORT

PDNS_STATS_URL = "$PDNS_API_URL/servers/localhost/statistics"
PDNS_API_URL = "$PDNS_API_URL"
PDNS_API_KEY = "$PDNS_API_KEY"
PDNS_VERSION = "4.8.0"
EOF

  # Initialize DB and create admin user
  export FLASK_APP=powerdnsadmin/__init__.py
  flask db upgrade || true

  # Create admin user if not exists
  python3 - <<PY
import os
os.environ['FLASK_APP']='powerdnsadmin/__init__.py'
from powerdnsadmin import create_app
from powerdnsadmin.models.user import User
from powerdnsadmin import db
app = create_app()
with app.app_context():
    u = User.query.filter_by(username="${ADMIN_USERNAME}").first()
    if not u:
        u = User(username="${ADMIN_USERNAME}", password="${ADMIN_PASSWORD}", plain_text_password="${ADMIN_PASSWORD}", email="${ADMIN_EMAIL}", role_name='Administrator', confirmed=True)
        db.session.add(u)
        db.session.commit()
        print('Admin user created')
    else:
        print('Admin user already exists, skipping')
PY

  deactivate

  # Systemd service (gunicorn)
  cat > /etc/systemd/system/powerdns-admin.service <<EOF
[Unit]
Description=PowerDNS-Admin Gunicorn Service
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$PDA_DIR
Environment="PATH=$PDA_DIR/venv/bin"
ExecStart=$PDA_DIR/venv/bin/gunicorn -w 3 -b 127.0.0.1:$WEBUI_PORT "powerdnsadmin:create_app()"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable powerdns-admin
  systemctl restart powerdns-admin
}

configure_nginx_ssl() {
  log "Configuring nginx reverse proxy with self-signed SSL"
  mkdir -p /etc/nginx/ssl/pdns-admin
  if [[ ! -f /etc/nginx/ssl/pdns-admin/server.key ]]; then
    openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/nginx/ssl/pdns-admin/server.key -out /etc/nginx/ssl/pdns-admin/server.crt -days 3650 -subj "/CN=$SITE_FQDN"
    chmod 600 /etc/nginx/ssl/pdns-admin/server.key
  fi

  cat > /etc/nginx/sites-available/powerdns-admin <<EOF
server {
    listen 80;
    server_name $SITE_FQDN;
    return 301 https://$SITE_FQDN$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $SITE_FQDN;

    ssl_certificate     /etc/nginx/ssl/pdns-admin/server.crt;
    ssl_certificate_key /etc/nginx/ssl/pdns-admin/server.key;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://127.0.0.1:$WEBUI_PORT;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/powerdns-admin /etc/nginx/sites-enabled/powerdns-admin
  if [[ -f /etc/nginx/sites-enabled/default ]]; then rm -f /etc/nginx/sites-enabled/default; fi
  nginx -t
  systemctl enable nginx
  systemctl restart nginx
}

configure_ufw() {
  log "Configuring UFW firewall rules"
  ufw --force enable || true
  ufw allow $PDNS_RECURSOR_PORT/tcp
  ufw allow $PDNS_RECURSOR_PORT/udp
  ufw allow 80/tcp
  ufw allow 443/tcp
  # Do not expose 5300 (auth) externally
}

create_initial_zone() {
  log "Creating initial DNS zone and records ($DNS_ZONE)"
  # Ensure pdnsutil is installed (part of pdns-server)
  if ! pdnsutil list-all-zones | grep -q "^$DNS_ZONE$"; then
    pdnsutil create-zone "$DNS_ZONE" "dns.$DNS_ZONE"
  else
    info "Zone $DNS_ZONE already exists, skipping creation"
  fi
  # Basic NS + A records
  pdnsutil add-record "$DNS_ZONE" "dns" A "$DNS_SERVER_IP" || true
  # User-defined records
  add_rec() {
    local pair="$1"
    local name="${pair%%:*}"
    local ip="${pair#*:}"
    if [[ -n "$name" && -n "$ip" ]]; then
      pdnsutil add-record "$DNS_ZONE" "$name" A "$ip" || true
    fi
  }
  add_rec "${DNS_RECORD_1:-}"
  add_rec "${DNS_RECORD_2:-}"
  add_rec "${DNS_RECORD_3:-}"
}

write_credentials() {
  log "Writing credentials to $CREDENTIALS_FILE"
  cat > "$CREDENTIALS_FILE" <<EOF
PowerDNS Automated Deployment - Credentials and Endpoints
Generated on: $(date -Is)

System
- OS: Ubuntu 24.04 LTS (expected)
- DNS Server IP: $DNS_SERVER_IP
- Internal Network: $INTERNAL_NETWORK
- VPN Network: $VPN_NETWORK

Components and Ports
- PowerDNS Authoritative: port $PDNS_AUTH_PORT (local only)
- PowerDNS Recursor: port $PDNS_RECURSOR_PORT (public)
- PowerDNS API URL: $PDNS_API_URL
- PowerDNS-Admin Backend: 127.0.0.1:$WEBUI_PORT
- Web UI (HTTPS): https://$SITE_FQDN/

Database (PostgreSQL)
- PDNS DB: name=$DB_NAME, user=$DB_USER, password=$DB_PASSWORD
- PDNS-Admin DB: name=$PDA_DB_NAME, user=$PDA_DB_USER, password=$PDA_DB_PASSWORD

Authentication / Secrets
- PowerDNS API Key: $PDNS_API_KEY
- PowerDNS-Admin SECRET_KEY: $PDNS_ADMIN_SECRET_KEY
- PowerDNS-Admin API Key (to generate via UI if needed): $PDNS_ADMIN_API_KEY
- Admin user: $ADMIN_USERNAME
- Admin password: $ADMIN_PASSWORD
- Admin email: $ADMIN_EMAIL

DNS Zone Initialized
- Zone: $DNS_ZONE
- Records:
  - ${DNS_RECORD_1:-}
  - ${DNS_RECORD_2:-}
  - ${DNS_RECORD_3:-}

Next Steps
1. Point your browser to https://$SITE_FQDN/ (accept the self-signed certificate warning).
2. Login with the admin credentials above.
3. In Settings -> PDNS, verify API URL and API key are set. Server ID is 'localhost'.
4. Optionally replace the SSL certificate with a trusted certificate.
5. Point your clients to DNS server $DNS_SERVER_IP (UDP/TCP $PDNS_RECURSOR_PORT).
EOF
  chmod 600 "$CREDENTIALS_FILE"
}

final_summary() {
  echo
  echo "================ INSTALLATION COMPLETE ================"
  echo "PowerDNS-Admin URL: https://$SITE_FQDN/"
  echo "Admin user: $ADMIN_USERNAME"
  echo "Admin password: $ADMIN_PASSWORD"
  echo "Credentials file: $CREDENTIALS_FILE"
  echo "Services: pdns, pdns-recursor, powerdns-admin, nginx"
  echo "======================================================"
}

main() {
  require_root
  ensure_config
  set_defaults
  apt_install_packages
  setup_postgres
  configure_pdns_authoritative
  configure_pdns_recursor
  install_powerdns_admin
  configure_nginx_ssl
  configure_ufw
  create_initial_zone
  write_credentials
  final_summary
}

main "$@"
