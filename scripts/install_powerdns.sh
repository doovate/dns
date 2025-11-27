#!/usr/bin/env bash
set -euo pipefail

# Instalador integral de PowerDNS + Recursor + PowerDNS-Admin + Nginx en Ubuntu 24.04 LTS
# Arquitectura:
# - Authoritative en 127.0.0.1:5300 (MySQL backend)
# - Recursor en 0.0.0.0:53 con forward a Authoritative para zonas internas y a 8.8.8.8/1.1.1.1 para resto
# - PowerDNS-Admin en 127.0.0.1:8000 tras Nginx
# - MariaDB como base de datos

# Valores por defecto (modificables por flags)
DB_NAME="powerdns"
DB_USER="powerdns"
DB_PASS="password"
DOMAIN="doovate.com"
DNS_IP="192.168.25.60"
INTERNAL_CIDR="192.168.24.0/22"
VPN_CIDR="10.66.66.0/24"
ADMIN_FQDN="powerdns.example.com"
ENABLE_CERTBOT="false"
# API_KEY puede venir del archivo de configuración; si queda vacío, se generará más adelante
API_KEY=""

usage() {
  cat <<EOF
Uso: sudo bash $0 [opciones]

Opciones:
  --db-name NOMBRE                 (def: ${DB_NAME})
  --db-user USUARIO               (def: ${DB_USER})
  --db-password CLAVE             (def: ${DB_PASS})
  --domain FQDN_INTERNO           (def: ${DOMAIN})
  --dns-ip IP_SERVIDOR            (def: ${DNS_IP})
  --internal-cidr CIDR            (def: ${INTERNAL_CIDR})
  --vpn-cidr CIDR                 (def: ${VPN_CIDR})
  --admin-fqdn FQDN               (def: ${ADMIN_FQDN})
  --enable-certbot                Habilita emisión SSL con Certbot (requiere DNS público apuntando al servidor)
  -h, --help                      Muestra esta ayuda
EOF
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --db-name) DB_NAME="$2"; shift 2;;
      --db-user) DB_USER="$2"; shift 2;;
      --db-password) DB_PASS="$2"; shift 2;;
      --domain) DOMAIN="$2"; shift 2;;
      --dns-ip) DNS_IP="$2"; shift 2;;
      --internal-cidr) INTERNAL_CIDR="$2"; shift 2;;
      --vpn-cidr) VPN_CIDR="$2"; shift 2;;
      --admin-fqdn) ADMIN_FQDN="$2"; shift 2;;
      --enable-certbot) ENABLE_CERTBOT="true"; shift;;
      -h|--help) usage; exit 0;;
      *) echo "Opción desconocida: $1" >&2; usage; exit 1;;
    esac
  done
}

load_env_config() {
  local candidates=(
    "${PWD}/powerdns.env"
    "${PWD}/config/powerdns.env"
    "/etc/powerdns-installer/powerdns.env"
  )
  for p in "${candidates[@]}"; do
    if [[ -f "$p" ]]; then
      echo "Cargando configuración desde: $p"
      # shellcheck disable=SC1090
      . "$p"
      CONFIG_SOURCE="$p"
      break
    fi
  done
}

normalize_booleans() {
  case "${ENABLE_CERTBOT,,}" in
    1|y|yes|true) ENABLE_CERTBOT="true";;
    0|n|no|false|"" ) ENABLE_CERTBOT="false";;
  esac
}

apt_update() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
}

install_mariadb() {
  apt-get install -y mariadb-server pdns-backend-mysql
  systemctl enable --now mariadb
}

setup_database() {
  mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
  mariadb "${DB_NAME}" < /usr/share/pdns-backend-mysql/schema/schema.mysql.sql
}

disable_systemd_resolved() {
  if systemctl is-enabled systemd-resolved >/dev/null 2>&1; then
    systemctl disable --now systemd-resolved || true
  else
    systemctl stop systemd-resolved || true
  fi
  rm -f /etc/resolv.conf
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf
}

install_powerdns_authoritative() {
  apt-get install -y pdns-server
  mkdir -p /etc/powerdns/pdns.d
  cat >/etc/powerdns/pdns.d/pdns.local.gmysql.conf <<CONF
launch+=gmysql

# Conexión MySQL
gmysql-host=127.0.0.1
gmysql-port=3306
gmysql-dbname=${DB_NAME}
gmysql-user=${DB_USER}
gmysql-password=${DB_PASS}

# DNSSEC habilitado
gmysql-dnssec=yes
CONF

  # Configuración principal: puerto 5300 y API en 8081
  sed -i 's/^#*\s*local-address=.*/local-address=0.0.0.0, ::/g' /etc/powerdns/pdns.conf || true
  sed -i 's/^#*\s*local-port=.*/local-port=5300/g' /etc/powerdns/pdns.conf || echo "local-port=5300" >> /etc/powerdns/pdns.conf
  {
    echo "api=yes"
    echo "api-key=${API_KEY}"
    echo "webserver=yes"
    echo "webserver-address=127.0.0.1"
    echo "webserver-port=8081"
  } >> /etc/powerdns/pdns.conf

  systemctl enable --now pdns
}

install_powerdns_recursor() {
  apt-get install -y pdns-recursor
  cat >/etc/powerdns/recursor.conf <<CONF
# Escucha en 53/UDP+TCP en todas las interfaces
local-address=0.0.0.0, ::
local-port=53

# ACL de redes permitidas
allow-from=127.0.0.0/8, ::1, ${INTERNAL_CIDR}, ${VPN_CIDR}

# Reenviar zona interna al Authoritative en 127.0.0.1:5300
forward-zones=${DOMAIN}=127.0.0.1:5300

# Ejemplos de reverse (ajusta según tus rangos):
# 24.168.192.in-addr.arpa=127.0.0.1:5300
# 66.66.10.in-addr.arpa=127.0.0.1:5300

# Forward público para el resto
forward-zones-recurse=.=8.8.8.8;1.1.1.1

max-cache-entries=200000
max-negative-ttl=60
max-cache-ttl=3600

thread-count=4

CONF
  systemctl enable --now pdns-recursor
}

install_powerdns_admin() {
  apt-get install -y python3-venv python3-dev python3-mysqldb libpq-dev gcc libmysqlclient-dev libsasl2-dev libffi-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev pkg-config git curl nginx

  # NodeJS + Yarn
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnpkg-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/yarnpkg-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get update && apt-get install -y yarn nodejs

  # Código de PowerDNS-Admin
  mkdir -p /opt/web
  if [[ ! -d /opt/web/powerdns-admin ]]; then
    git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git /opt/web/powerdns-admin
  fi

  cd /opt/web/powerdns-admin
  python3 -m venv flask
  /opt/web/powerdns-admin/flask/bin/pip install --upgrade pip setuptools wheel
  /opt/web/powerdns-admin/flask/bin/pip install -r requirements.txt

  # Config DB en default_config.py
  sed -i "s#^SQLA_DB_USER\s*=.*#SQLA_DB_USER = '${DB_USER}'#" powerdnsadmin/default_config.py || echo "SQLA_DB_USER = '${DB_USER}'" >> powerdnsadmin/default_config.py
  sed -i "s#^SQLA_DB_PASSWORD\s*=.*#SQLA_DB_PASSWORD = '${DB_PASS}'#" powerdnsadmin/default_config.py || echo "SQLA_DB_PASSWORD = '${DB_PASS}'" >> powerdnsadmin/default_config.py
  sed -i "s#^SQLA_DB_HOST\s*=.*#SQLA_DB_HOST = '127.0.0.1'#" powerdnsadmin/default_config.py || echo "SQLA_DB_HOST = '127.0.0.1'" >> powerdnsadmin/default_config.py
  sed -i "s#^SQLA_DB_NAME\s*=.*#SQLA_DB_NAME = '${DB_NAME}'#" powerdnsadmin/default_config.py || echo "SQLA_DB_NAME = '${DB_NAME}'" >> powerdnsadmin/default_config.py
  sed -i "s#^SQLALCHEMY_TRACK_MODIFICATIONS\s*=.*#SQLALCHEMY_TRACK_MODIFICATIONS = True#" powerdnsadmin/default_config.py || echo "SQLALCHEMY_TRACK_MODIFICATIONS = True" >> powerdnsadmin/default_config.py

  # Migraciones y assets
  export FLASK_APP=powerdnsadmin/__init__.py
  /opt/web/powerdns-admin/flask/bin/flask db upgrade
  yarn install --pure-lockfile
  /opt/web/powerdns-admin/flask/bin/flask assets build

  # Servicio systemd de PowerDNS-Admin
  cat >/etc/systemd/system/powerdns-admin.service <<UNIT
[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/opt/web/powerdns-admin
ExecStart=/opt/web/powerdns-admin/flask/bin/gunicorn -w 4 -b 127.0.0.1:8000 "powerdnsadmin:create_app()"
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable --now powerdns-admin
}

configure_nginx() {
  cat >/etc/nginx/sites-available/powerdns-admin <<NGINX
server {
    listen 80;
    server_name ${ADMIN_FQDN};

    access_log /var/log/nginx/powerdns-admin.access.log;
    error_log  /var/log/nginx/powerdns-admin.error.log;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static/ {
        alias /opt/web/powerdns-admin/powerdnsadmin/static/;
        access_log off;
    }
}
NGINX
  ln -sf /etc/nginx/sites-available/powerdns-admin /etc/nginx/sites-enabled/powerdns-admin
  nginx -t
  systemctl restart nginx
}

maybe_enable_ssl() {
  if [[ "${ENABLE_CERTBOT}" == "true" ]]; then
    apt-get install -y certbot python3-certbot-nginx
    certbot --nginx --redirect -d "${ADMIN_FQDN}" || echo "Certbot falló; revisa DNS público y puertos 80/443."
  fi
}

configure_resolv_to_local() {
  # Hacer que el propio sistema consulte al recursor local
  printf "nameserver 127.0.0.1\n" > /etc/resolv.conf
}

ufw_open_ports() {
  if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -qi active; then
      ufw allow 53
      ufw allow 53/udp
      ufw allow 80/tcp
      ufw allow 443/tcp
    fi
  fi
}

show_summary() {
  cat <<OUT

Instalación completada.
- Dominio interno: ${DOMAIN}
- PowerDNS Authoritative: puerto 5300 (API key: ${API_KEY})
- PowerDNS Recursor: puerto 53 (ACL: ${INTERNAL_CIDR}, ${VPN_CIDR}, localhost)
- PowerDNS-Admin vía Nginx: http://${ADMIN_FQDN}/  (usa --enable-certbot para HTTPS)
- Configura PowerDNS-Admin con la API Key anterior y URL http://127.0.0.1:8081

Archivos relevantes:
- /etc/powerdns/pdns.conf
- /etc/powerdns/pdns.d/pdns.local.gmysql.conf
- /etc/powerdns/recursor.conf
- /etc/systemd/system/powerdns-admin.service
- /etc/nginx/sites-available/powerdns-admin

Siguientes pasos recomendados:
- Ingresar a PowerDNS-Admin, crear el usuario admin inicial, y añadir la instancia de PowerDNS con la API Key.
- Crear la zona ${DOMAIN} y registros necesarios.
- Opcional: configurar reversas adecuadas para tus rangos internos.
OUT
}

write_persisted_config() {
  mkdir -p /etc/powerdns-installer
  cat > /etc/powerdns-installer/powerdns.env <<ENV
# Archivo central de configuración de PowerDNS Installer
# Edita estos valores y vuelve a ejecutar el instalador para aplicarlos.
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"
DOMAIN="${DOMAIN}"
DNS_IP="${DNS_IP}"
INTERNAL_CIDR="${INTERNAL_CIDR}"
VPN_CIDR="${VPN_CIDR}"
ADMIN_FQDN="${ADMIN_FQDN}"
ENABLE_CERTBOT="${ENABLE_CERTBOT}"
API_KEY="${API_KEY}"
ENV
}

ensure_api_key() {
  if [[ -z "${API_KEY}" ]]; then
    API_KEY="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)"
  fi
}

main() {
  require_root
  load_env_config
  parse_args "$@"
  normalize_booleans
  ensure_api_key
  apt_update
  install_mariadb
  setup_database
  disable_systemd_resolved
  install_powerdns_authoritative
  install_powerdns_recursor
  install_powerdns_admin
  configure_nginx
  maybe_enable_ssl
  configure_resolv_to_local
  ufw_open_ports
  write_persisted_config
  show_summary
}

main "$@"
