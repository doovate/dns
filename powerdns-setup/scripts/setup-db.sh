#!/usr/bin/env bash
# Setup database for PowerDNS (PostgreSQL default, MySQL optional)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/config.env"

log() { echo -e "\e[1;32m[DB]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

DB_TYPE=${DB_TYPE:-postgresql}
DB_NAME=${DB_NAME:-powerdns}
DB_USER=${DB_USER:-pdns}
DB_PASSWORD=${DB_PASSWORD:-}

if [[ -z "$DB_PASSWORD" ]]; then
  err "DB_PASSWORD is empty. Generate it first or leave empty in config.env and run install.sh."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if [[ "$DB_TYPE" == "postgresql" ]]; then
  log "Installing PostgreSQL packages..."
  apt-get update -y
  apt-get install -y postgresql postgresql-contrib
  systemctl enable --now postgresql

  log "Creating database and user if not exists..."
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';"
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"

  log "Applying PowerDNS schema if needed..."
  if ! sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='domains'" | grep -q 1; then
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
CREATE INDEX IF NOT EXISTS records_name_index ON records(name);
CREATE INDEX IF NOT EXISTS records_order_idx ON records(ordername);
CREATE INDEX IF NOT EXISTS domain_id_idx ON records(domain_id);

CREATE TABLE IF NOT EXISTS supermasters (
  ip VARCHAR(64) NOT NULL,
  nameserver VARCHAR(255) NOT NULL,
  account VARCHAR(40) DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS comments (
  id SERIAL PRIMARY KEY,
  domain_id INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(10) NOT NULL,
  modified_at INT NOT NULL,
  account VARCHAR(40) DEFAULT NULL,
  comment VARCHAR(65535) NOT NULL
);
CREATE INDEX IF NOT EXISTS comments_domain_id_idx ON comments (domain_id);
CREATE INDEX IF NOT EXISTS comments_name_type_idx ON comments (name,type);
CREATE INDEX IF NOT EXISTS comments_order_idx ON comments (domain_id, modified_at);

CREATE TABLE IF NOT EXISTS domainmetadata (
  id SERIAL PRIMARY KEY,
  domain_id INT REFERENCES domains(id) ON DELETE CASCADE,
  kind VARCHAR(32),
  content TEXT
);
CREATE INDEX IF NOT EXISTS domainmetaidindex ON domainmetadata(domain_id);

CREATE TABLE IF NOT EXISTS cryptokeys (
  id SERIAL PRIMARY KEY,
  domain_id INT REFERENCES domains(id) ON DELETE CASCADE,
  flags INT,
  active BOOL,
  content TEXT
);
CREATE INDEX IF NOT EXISTS domainidindex ON cryptokeys(domain_id);

CREATE TABLE IF NOT EXISTS tsigkeys (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  algorithm VARCHAR(50),
  secret VARCHAR(255)
);
CREATE UNIQUE INDEX IF NOT EXISTS namealgoindex ON tsigkeys(name, algorithm);
SQL
  fi

elif [[ "$DB_TYPE" == "mysql" ]]; then
  log "Installing MariaDB (MySQL) packages..."
  apt-get update -y
  apt-get install -y mariadb-server
  systemctl enable --now mariadb

  log "Creating database and user if not exists..."
  mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
  # Apply schema
  mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS domains (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  master VARCHAR(128) DEFAULT NULL,
  last_check INT DEFAULT NULL,
  type VARCHAR(6) NOT NULL,
  notified_serial INT DEFAULT NULL,
  account VARCHAR(40) DEFAULT NULL,
  UNIQUE KEY name_index (name)
);
CREATE TABLE IF NOT EXISTS records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT DEFAULT NULL,
  name VARCHAR(255) DEFAULT NULL,
  type VARCHAR(10) DEFAULT NULL,
  content VARCHAR(65535) DEFAULT NULL,
  ttl INT DEFAULT NULL,
  prio INT DEFAULT NULL,
  change_date INT DEFAULT NULL,
  disabled TINYINT(1) DEFAULT 0,
  ordername VARCHAR(255) DEFAULT NULL,
  auth TINYINT(1) DEFAULT 1,
  KEY records_name_index (name),
  KEY records_order_idx (ordername),
  KEY domain_id_idx (domain_id)
);
CREATE TABLE IF NOT EXISTS supermasters (
  ip VARCHAR(64) NOT NULL,
  nameserver VARCHAR(255) NOT NULL,
  account VARCHAR(40) DEFAULT NULL
);
CREATE TABLE IF NOT EXISTS comments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT NOT NULL,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(10) NOT NULL,
  modified_at INT NOT NULL,
  account VARCHAR(40) DEFAULT NULL,
  comment VARCHAR(65535) NOT NULL,
  KEY comments_domain_id_idx (domain_id),
  KEY comments_name_type_idx (name,type),
  KEY comments_order_idx (domain_id, modified_at)
);
CREATE TABLE IF NOT EXISTS domainmetadata (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT,
  kind VARCHAR(32),
  content TEXT,
  KEY domainmetaidindex (domain_id)
);
CREATE TABLE IF NOT EXISTS cryptokeys (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT,
  flags INT,
  active TINYINT(1),
  content TEXT,
  KEY domainidindex (domain_id)
);
CREATE TABLE IF NOT EXISTS tsigkeys (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255),
  algorithm VARCHAR(50),
  secret VARCHAR(255),
  UNIQUE KEY namealgoindex (name, algorithm)
);
SQL
else
  err "Unsupported DB_TYPE: $DB_TYPE"
  exit 1
fi

log "Database setup completed."
