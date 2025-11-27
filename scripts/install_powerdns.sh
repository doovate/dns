#!/usr/bin/env bash
set -euo pipefail

# PowerDNS + optional Recursor, dnsdist and PowerDNS-Admin installer for Debian/Ubuntu
# Usage examples:
#   sudo bash scripts/install_powerdns.sh --db pgsql --with-recursor --with-dnsdist --with-admin \
#        --external-ip 203.0.113.10 --lan-cidr 192.168.1.0/24
#   sudo bash scripts/install_powerdns.sh --db mysql
# Flags:
#   --db [pgsql|mysql]          Choose database backend (default: pgsql)
#   --with-recursor             Install pdns-recursor
#   --with-dnsdist              Install dnsdist
#   --with-admin                Install PowerDNS-Admin frontend
#   --external-ip <IP>          External server IP for examples (dnsdist/pdns)
#   --lan-cidr <CIDR>           LAN CIDR for ACL examples
#   --non-interactive           Do not prompt; assume yes
#   --dry-run                   Print actions only (no changes)

DB_TYPE="pgsql"
WITH_RECURSOR=0
WITH_DNSDIST=0
WITH_ADMIN=0
EXTERNAL_IP=""
LAN_CIDR="127.0.0.1/32"
ZONE=""
UPSTREAMS="8.8.8.8;1.1.1.1"
NONINTERACTIVE=0
DRYRUN=0

log() { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
run() { if [[ $DRYRUN -eq 1 ]]; then echo "DRYRUN: $*"; else eval "$*"; fi }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB_TYPE=${2:-pgsql}; shift 2;;
    --with-recursor) WITH_RECURSOR=1; shift;;
    --with-dnsdist) WITH_DNSDIST=1; shift;;
    --with-admin) WITH_ADMIN=1; shift;;
    --external-ip) EXTERNAL_IP=${2:-}; shift 2;;
    --lan-cidr) LAN_CIDR=${2:-}; shift 2;;
    --zone) ZONE=${2:-}; shift 2;;
    --upstreams) UPSTREAMS=${2:-}; shift 2;;
    --non-interactive) NONINTERACTIVE=1; shift;;
    --dry-run) DRYRUN=1; shift;;
    *) warn "Unknown arg: $1"; shift;;
  esac
  done

if [[ $EUID -ne 0 ]]; then
  warn "Please run as root (sudo)."; exit 1
fi

if ! command -v lsb_release >/dev/null 2>&1; then
  run "apt-get update"
  run "apt-get install -y lsb-release"
fi

os_label=$(lsb_release -sa 2>/dev/null|head -n 1|tr '[:upper:]' '[:lower:]' || true)
rel_codename=$(lsb_release -cs)

if [[ -z "$os_label" || -z "$rel_codename" ]]; then
  warn "Unsupported distribution. lsb_release not available."; exit 1
fi

log "Detected OS: $os_label $rel_codename"

workpath="/opt/pdns_install"
run "mkdir -p $workpath"

log "Installing base dependencies"
run "apt-get update"
run "apt-get install -y software-properties-common gnupg2 curl ca-certificates wget apt-transport-https jq"

log "Adding PowerDNS repository keys"
run "wget -O- https://repo.powerdns.com/CBC8B383-pub.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/pdns_master.gpg"
run "wget -O- https://repo.powerdns.com/FD380FBB-pub.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/pdns_stable.gpg"

log "Adding PowerDNS APT sources"
repo_auth="deb [arch=amd64] http://repo.powerdns.com/${os_label} ${rel_codename}-auth-49 main"
repo_rec="deb [arch=amd64] http://repo.powerdns.com/${os_label} ${rel_codename}-rec-52 main"
repo_dnsdist="deb [arch=amd64] http://repo.powerdns.com/${os_label} ${rel_codename}-dnsdist-20 main"
run "echo '$repo_auth' > /etc/apt/sources.list.d/pdns-auth.list"
run "echo '$repo_rec'  > /etc/apt/sources.list.d/pdns-rec.list"
run "echo '$repo_dnsdist' > /etc/apt/sources.list.d/dnsdist.list"
run "bash -lc 'cat > /etc/apt/preferences.d/pdns <<EOF
Package: pdns-*
Pin: origin repo.powerdns.com
Pin-Priority: 600
EOF'"
run "bash -lc 'cat > /etc/apt/preferences.d/dnsdist <<EOF
Package: dnsdist*
Pin: origin repo.powerdns.com
Pin-Priority: 600
EOF'"

if [[ "$DB_TYPE" == "mysql" ]]; then
  log "Configuring MariaDB repository"
  run "wget -O- https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/mariadb.gpg"
  run "bash -lc 'cat > /etc/apt/sources.list.d/mariadb.list <<EOF
# MariaDB Repository List
deb [arch=amd64,arm64,ppc64el,s390x] https://mirrors.ukfast.co.uk/sites/mariadb/repo/10.5/${os_label} ${rel_codename} main
deb-src https://mirrors.ukfast.co.uk/sites/mariadb/repo/10.5/${os_label} ${rel_codename} main
EOF'"
else
  log "Configuring PostgreSQL repository"
  run "wget -O- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/postgresql.gpg"
  run "echo 'deb http://apt.postgresql.org/pub/repos/apt ${rel_codename}-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
fi

run "apt-get update -y"

if [[ "$DB_TYPE" == "mysql" ]]; then
  log "Installing MariaDB Server"
  run "apt-get install -y mariadb-server"
else
  log "Installing PostgreSQL Server"
  run "apt-get install -y postgresql"
  run "systemctl enable postgresql"
  run "systemctl start postgresql"
fi

log "Generating credentials"
pdns_db="pdns"
pdns_db_user="pdnsadmin"
pdns_pwd=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
pdnsadmin_salt=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
pdns_apikey=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)

cred_file="$workpath/db_credentials"
{
  echo "pdns_db=$pdns_db"
  echo "pdns_db_user=$pdns_db_user"
  echo "pdns_pwd=$pdns_pwd"
  echo "pdnsadmin_salt=$pdnsadmin_salt"
  echo "pdns_apikey=$pdns_apikey"
  echo "workpath=$workpath"
  echo "systemReleaseVersion=$rel_codename"
  echo "osLabel=$os_label"
  echo "db_type=$DB_TYPE"
} | run "tee $cred_file >/dev/null"
run "chown root:root $cred_file"
run "chmod 640 $cred_file"

log "Creating database and user"
if [[ "$DB_TYPE" == "mysql" ]]; then
  tmp_sql="$workpath/pdns-createdb-my.sql"
  cat > "$tmp_sql" <<SQL
-- PowerDNS MySQL/MariaDB Create DB File
CREATE DATABASE IF NOT EXISTS ${pdns};
CREATE DATABASE IF NOT EXISTS ${pdns_db};
GRANT ALL ON ${pdns_db}.* TO '${pdns_db_user}'@'localhost' IDENTIFIED BY '${pdns_pwd}';
FLUSH PRIVILEGES;
SQL
  run "mariadb -u root < $tmp_sql"
else
  tmp_sql="$workpath/pdns-createdb-pg.sql"
  cat > "$tmp_sql" <<SQL
-- PowerDNS PGSQL Create DB File
DO $$ BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${pdns_db_user}') THEN
      CREATE ROLE ${pdns_db_user} LOGIN PASSWORD '${pdns_pwd}';
   END IF;
END $$;
DO $$ BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${pdns_db}') THEN
      CREATE DATABASE ${pdns_db} OWNER ${pdns_db_user};
   END IF;
END $$;
GRANT ALL PRIVILEGES ON DATABASE ${pdns_db} TO ${pdns_db_user};
SQL
  run "sudo -u postgres psql < $tmp_sql"
fi

log "Installing PowerDNS components"
if [[ "$DB_TYPE" == "mysql" ]]; then
  run "apt-get install -y pdns-backend-mysql"
else
  run "apt-get install -y pdns-backend-pgsql"
fi
run "apt-get install -y pdns-server"
if [[ $WITH_RECURSOR -eq 1 ]]; then run "apt-get install -y pdns-recursor"; fi
if [[ $WITH_DNSDIST -eq 1 ]]; then run "apt-get install -y dnsdist"; fi

# Disable systemd-resolved (optional; ask unless non-interactive)
if systemctl is-enabled systemd-resolved >/dev/null 2>&1; then
  if [[ $NONINTERACTIVE -eq 1 ]]; then
    run "systemctl disable systemd-resolved || true"; run "systemctl stop systemd-resolved || true"
  else
    read -r -p "Disable systemd-resolved and stop it now? [y/N] " ans
    if [[ ${ans,,} == y* ]]; then run "systemctl disable systemd-resolved"; run "systemctl stop systemd-resolved"; fi
  fi
fi

log "Populating PDNS database schema"
db_config_path="/etc/powerdns/pdns.d"
db_config_file="$db_config_path/g${DB_TYPE}.conf"
run "mkdir -p $db_config_path"

if [[ "$DB_TYPE" == "mysql" ]]; then
  run "mariadb -u ${pdns_db_user} -p${pdns_pwd} ${pdns_db} < /usr/share/pdns-backend-mysql/schema/schema.mysql.sql"
  run "cp /usr/share/doc/pdns-backend-mysql/examples/gmysql.conf $db_config_file"
else
  export PGPASSWORD="$pdns_pwd"
  run "psql -U ${pdns_db_user} -h 127.0.0.1 -d ${pdns_db} < /usr/share/pdns-backend-pgsql/schema/schema.pgsql.sql"
  unset PGPASSWORD
  run "cp /usr/share/doc/pdns-backend-pgsql/examples/gpgsql.conf $db_config_file"
fi

run "sed -i 's/^g.*-dbname=.*/g${DB_TYPE}-dbname=${pdns_db}/' $db_config_file"
run "sed -i 's/^g.*-host=.*/g${DB_TYPE}-host=127.0.0.1/' $db_config_file"
if [[ "$DB_TYPE" == "mysql" ]]; then
  run "sed -i 's/^g.*-port=.*/g${DB_TYPE}-port=3306/' $db_config_file"
else
  run "sed -i 's/^g.*-port=.*/g${DB_TYPE}-port=5432/' $db_config_file"
fi
run "sed -i 's/^g.*-user=.*/g${DB_TYPE}-user=${pdns_db_user}/' $db_config_file"
run "sed -i 's/^g.*-password=.*/g${DB_TYPE}-password=${pdns_pwd}/' $db_config_file"
run "chmod 640 $db_config_file"
run "chown root:pdns $db_config_file"

log "Configuring pdns.conf API"
pdns_conf="/etc/powerdns/pdns.conf"
run "sed -i 's/^#\?api=.*/api=yes/' $pdns_conf || echo 'api=yes' >> $pdns_conf"
run "sed -i 's/^#\?webserver=.*/webserver=yes/' $pdns_conf || echo 'webserver=yes' >> $pdns_conf"
run "grep -q '^api-key=' $pdns_conf && sed -i 's/^api-key=.*/api-key=${pdns_apikey}/' $pdns_conf || echo 'api-key=${pdns_apikey}' >> $pdns_conf"
run "grep -q '^webserver-port=' $pdns_conf || echo 'webserver-port=8081' >> $pdns_conf"
if [[ -n "$LAN_CIDR" ]]; then
  run "grep -q '^webserver-allow-from=' $pdns_conf && sed -i 's/^webserver-allow-from=.*/webserver-allow-from=127.0.0.1,${LAN_CIDR}/' $pdns_conf || echo 'webserver-allow-from=127.0.0.1,${LAN_CIDR}' >> $pdns_conf"
fi

if [[ -n "$EXTERNAL_IP" ]]; then
  run "grep -q '^local-address=' $pdns_conf && sed -i 's/^local-address=.*/local-address=127.0.0.1, ${EXTERNAL_IP}/' $pdns_conf || echo 'local-address=127.0.0.1, ${EXTERNAL_IP}' >> $pdns_conf"
fi

# Adjust PDNS authoritative port if using recursor without dnsdist
if [[ $WITH_RECURSOR -eq 1 && $WITH_DNSDIST -eq 0 ]]; then
  # Move PDNS auth to port 5300 to avoid conflict with recursor on 53
  run "grep -q '^local-port=' $pdns_conf && sed -i 's/^local-port=.*/local-port=5300/' $pdns_conf || echo 'local-port=5300' >> $pdns_conf"
  # Bind auth only to localhost unless external IP explicitly set
  if ! grep -q '^local-address=' "$pdns_conf"; then
    run "echo 'local-address=127.0.0.1' >> $pdns_conf"
  fi
  run "systemctl restart pdns || systemctl restart pdns.service"
fi

# Configure recursor for internal clients and forwarding
if [[ $WITH_RECURSOR -eq 1 ]]; then
  rec_conf="/etc/powerdns/recursor.conf"
  run "touch $rec_conf"
  # Listen on provided external IP or all
  if [[ -n "$EXTERNAL_IP" ]]; then
    run "grep -q '^local-address=' $rec_conf && sed -i 's/^local-address=.*/local-address=${EXTERNAL_IP}/' $rec_conf || echo 'local-address=${EXTERNAL_IP}' >> $rec_conf"
  fi
  # Allow internal networks
  allow_list="127.0.0.1"
  if [[ -n "$LAN_CIDR" ]]; then allow_list="$allow_list,$LAN_CIDR"; fi
  run "grep -q '^allow-from=' $rec_conf && sed -i 's/^allow-from=.*/allow-from='\"$allow_list\"'/' $rec_conf || echo 'allow-from='\"$allow_list\"'' >> $rec_conf"
  # Forward authoritative zone to local PDNS auth on 5300 if zone provided
  if [[ -n "$ZONE" ]]; then
    if grep -q '^forward-zones=' "$rec_conf"; then
      run "sed -i 's#^forward-zones=.*#forward-zones=${ZONE}=127.0.0.1:5300#' $rec_conf"
    else
      run "echo 'forward-zones=${ZONE}=127.0.0.1:5300' >> $rec_conf"
    fi
  fi
  # Forward everything else to upstreams
  if grep -q '^forward-zones-recurse=' "$rec_conf"; then
    run "sed -i 's#^forward-zones-recurse=.*#forward-zones-recurse=.=${UPSTREAMS}#' $rec_conf"
  else
    run "echo 'forward-zones-recurse=.=${UPSTREAMS}' >> $rec_conf"
  fi
  run "systemctl restart pdns-recursor || true"
fi

# dnsdist example
if [[ $WITH_DNSDIST -eq 1 ]]; then
  if [[ -n "$EXTERNAL_IP" ]]; then
    cat > "/etc/dnsdist/dnsdist.conf" <<CONF
setLocal('${EXTERNAL_IP}:53')
setACL({'0.0.0.0/0', '::/0'})
newServer({address='127.0.0.1:5300', pool='auth'})
newServer({address='127.0.0.1:5301', pool='recursor'})
recursive_ips = newNMG()
recursive_ips:addMask('127.0.0.0/8')
recursive_ips:addMask('${LAN_CIDR}')
addAction(NetmaskGroupRule(recursive_ips), PoolAction('recursor'))
addAction(AllRule(), PoolAction('auth'))
setSecurityPollSuffix("")
CONF
    run "systemctl restart dnsdist || true"
  else
    warn "dnsdist requested but --external-ip not provided. Skipping config example."
  fi
fi

# Optional PowerDNS-Admin frontend
if [[ $WITH_ADMIN -eq 1 ]]; then
  log "Installing PowerDNS-Admin dependencies"
  run "apt-get install -y nginx python3-dev python3-venv libsasl2-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config virtualenv build-essential libmariadb-dev git libpq-dev python3-flask"
  # Node.js 20
  run "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
  run "apt-get update -y"
  run "apt-get install -y nodejs"
  # Yarn
  run "wget -O- https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/yarnpkg.gpg"
  run "echo 'deb https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list"
  run "apt-get update -y && apt-get install -y yarn"

  PDNS_WEB_DIR="/var/www/html/pdns"
  if [[ ! -d "$PDNS_WEB_DIR" ]]; then
    run "git clone https://github.com/PowerDNS-Admin/PowerDNS-Admin.git $PDNS_WEB_DIR"
  fi
  run "bash -lc 'cd $PDNS_WEB_DIR && virtualenv -p python3 flask'"
  run "bash -lc 'source $PDNS_WEB_DIR/flask/bin/activate && sed -i "s/PyYAML==5.4/PyYAML==6.0/g" requirements.txt && pip install --upgrade pip && pip install -r requirements.txt && deactivate'"

  prod_config="$PDNS_WEB_DIR/configs/production.py"
  run "cp $PDNS_WEB_DIR/configs/development.py $prod_config"
  run "sed -i "s/^FILESYSTEM_SESSIONS_ENABLED = .*/FILESYSTEM_SESSIONS_ENABLED = True/" $prod_config"
  run "sed -i "s/^SALT = .*/SALT = '${pdnsadmin_salt}'/" $prod_config"
  run "sed -i "s/^SECRET_KEY = .*/SECRET_KEY = '${pdns_apikey}'/" $prod_config"
  run "sed -i "s/^SQLA_DB_PASSWORD = .*/SQLA_DB_PASSWORD = '${pdns_pwd}'/" $prod_config"
  run "sed -i "s/^SQLA_DB_NAME = .*/SQLA_DB_NAME = '${pdns_db}'/" $prod_config"
  run "sed -i "s/^SQLA_DB_USER = .*/SQLA_DB_USER = '${pdns_db_user}'/" $prod_config"
  run "sed -i 's/#import urllib.parse/import urllib.parse/' $prod_config"

  if [[ "$DB_TYPE" == "mysql" ]]; then db_port=3306; sqlalchemy_prefix="mysql"; else db_port=5432; sqlalchemy_prefix="postgresql"; fi
  if ! grep -q '^SQLA_DB_PORT' "$prod_config"; then
    run "bash -lc 'sed -i "/^SQLA_DB_USER.*/a SQLA_DB_PORT = ${db_port}" $prod_config'"
  else
    run "sed -i "s/^SQLA_DB_PORT = .*/SQLA_DB_PORT = ${db_port}/" $prod_config"
  fi

  run "bash -lc 'cat >> $prod_config <<EOF
SQLALCHEMY_DATABASE_URI = '${sqlalchemy_prefix}://{}:{}@{}/{}'.format(
    urllib.parse.quote_plus(SQLA_DB_USER),
    urllib.parse.quote_plus(SQLA_DB_PASSWORD),
    SQLA_DB_HOST,
    SQLA_DB_NAME
)
EOF'"
  run "sed -i "s/^SQLALCHEMY_DATABASE_URI = 'sqlite.*/# &/" $prod_config"

  # Build DB and assets
  run "bash -lc 'cd $PDNS_WEB_DIR && source ./flask/bin/activate && export FLASK_APP=powerdnsadmin/__init__.py && export FLASK_CONF=../configs/production.py && flask db upgrade && yarn install --pure-lockfile && flask assets build && deactivate'"

  # systemd service and socket
  run "install -d -m 0755 /etc/systemd/system"
  cat > /etc/systemd/system/pdnsadmin.service <<UNIT
[Unit]
Description=PowerDNS-Admin
Requires=pdnsadmin.socket
After=network.target

[Service]
PIDFile=/run/pdnsadmin/pid
User=pdns
Group=pdns
Environment=FLASK_CONF=../configs/production.py
WorkingDirectory=$PDNS_WEB_DIR
ExecStart=$PDNS_WEB_DIR/flask/bin/gunicorn --pid /run/pdnsadmin/pid --bind unix:/run/pdnsadmin/socket 'powerdnsadmin:create_app()'
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT

  cat > /etc/systemd/system/pdnsadmin.socket <<UNIT
[Unit]
Description=PowerDNS-Admin socket

[Socket]
ListenStream=/run/pdnsadmin/socket

[Install]
WantedBy=sockets.target
UNIT

  # nginx site
  cat > /etc/nginx/sites-enabled/powerdns-admin.conf <<NGX
server {
  listen 80;
  server_name _;
  index index.html index.htm index.php;
  root $PDNS_WEB_DIR;
  access_log /var/log/nginx/pdnsadmin_access.log combined;
  error_log  /var/log/nginx/pdnsadmin_error.log;
  client_max_body_size 10m;
  client_body_buffer_size 128k;
  proxy_redirect off;
  proxy_connect_timeout 90;
  proxy_send_timeout 90;
  proxy_read_timeout 90;
  proxy_buffers 32 4k;
  proxy_buffer_size 8k;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_headers_hash_bucket_size 64;
  location ~ ^/static/  {
    include  /etc/nginx/mime.types;
    root $PDNS_WEB_DIR/powerdnsadmin;
    location ~*  \.(jpg|jpeg|png|gif)$ { expires 365d; }
    location ~* ^.+\.(css|js)$ { expires 7d; }
  }
  location / {
    proxy_pass http://unix:/run/pdnsadmin/socket;
    proxy_read_timeout 120;
    proxy_connect_timeout 120;
    proxy_redirect off;
  }
}
NGX

  run "id -u pdns >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin pdns || true"
  run "mkdir -p /run/pdnsadmin/"
  run "chown -R pdns: /run/pdnsadmin/"
  run "chown -R pdns: $PDNS_WEB_DIR/powerdnsadmin/"
  run "bash -lc "echo 'd /run/pdnsadmin 0755 pdns pdns -' >> /etc/tmpfiles.d/pdnsadmin.conf""

  run "nginx -t && systemctl restart nginx || true"
  run "systemctl daemon-reload"
  run "systemctl enable --now pdnsadmin.service pdnsadmin.socket || true"
fi

log "Installation complete"
echo "- Credentials saved at $cred_file"
echo "- PDNS API URL: http://localhost:8081"
if [[ $WITH_ADMIN -eq 1 ]]; then
  echo "- PowerDNS-Admin will be served via nginx on http://<server-ip>/"
fi
