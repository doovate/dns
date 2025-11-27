#!/usr/bin/env bash
set -Eeuo pipefail

# Paso 03: Configuración de base de datos (PostgreSQL por defecto)
# - Crea DB y usuario
# - Ajusta privilegios
# - Aplica esquema de PowerDNS si falta

source "$REPO_ROOT/scripts/lib/logging.sh"

generate_password() {
  openssl rand -base64 24 | tr -dc 'A-Za-z0-9_@#%^+=' | head -c 20
}

psql_exec() {
  sudo -u postgres psql -v ON_ERROR_STOP=1 -tAc "$1"
}

apply_pdns_schema_pg() {
  # Schema path may vary; use create statements directly when missing
  local table_exists
  table_exists=$(psql_exec "SELECT to_regclass('public.domains') IS NOT NULL")
  if [[ "$table_exists" != "t" ]]; then
    log_info "Aplicando esquema PowerDNS (PostgreSQL)"
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" <<'SQL'
CREATE TABLE domains (
    id                    SERIAL PRIMARY KEY,
    name                  VARCHAR(255) NOT NULL,
    master                VARCHAR(128) DEFAULT NULL,
    last_check            INT DEFAULT NULL,
    type                  VARCHAR(6) NOT NULL,
    notified_serial       BIGINT DEFAULT NULL,
    account               VARCHAR(40) DEFAULT NULL,
    CONSTRAINT c_lowercase_name CHECK (((name)::TEXT = lower((name)::TEXT)))
);
CREATE UNIQUE INDEX name_index ON domains(name);
CREATE TABLE records (
    id              BIGSERIAL PRIMARY KEY,
    domain_id       INT DEFAULT NULL,
    name            VARCHAR(255) DEFAULT NULL,
    type            VARCHAR(10) DEFAULT NULL,
    content         TEXT DEFAULT NULL,
    ttl             INT DEFAULT NULL,
    prio            INT DEFAULT NULL,
    disabled        BOOL DEFAULT 'f',
    ordername       VARCHAR(255),
    auth            BOOL DEFAULT 't',
    change_date     INT DEFAULT NULL
);
CREATE INDEX records_name_index ON records(name);
CREATE INDEX records_order_idx ON records(ordername);
CREATE INDEX records_domain_id_idx ON records(domain_id);
CREATE TABLE supermasters (
    ip        INET NOT NULL,
    nameserver VARCHAR(255) NOT NULL,
    account   VARCHAR(40) DEFAULT NULL
);
CREATE TABLE comments (
    id          SERIAL PRIMARY KEY,
    domain_id   INT NOT NULL,
    name        VARCHAR(255) NOT NULL,
    type        VARCHAR(10) NOT NULL,
    modified_at INT NOT NULL,
    account     VARCHAR(40) DEFAULT NULL,
    comment     TEXT NOT NULL
);
CREATE INDEX comments_domain_id_idx ON comments (domain_id);
CREATE INDEX comments_name_type_idx ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);
CREATE TABLE domainmetadata (
    id          SERIAL PRIMARY KEY,
    domain_id   INT REFERENCES domains(id) ON DELETE CASCADE,
    kind        VARCHAR(32),
    content     TEXT
);
CREATE INDEX domainmetaidindex ON domainmetadata(domain_id);
CREATE TABLE cryptokeys (
    id          SERIAL PRIMARY KEY,
    domain_id   INT REFERENCES domains(id) ON DELETE CASCADE,
    flags       INT NOT NULL,
    active      BOOL,
    content     TEXT
);
CREATE INDEX domainidindex ON cryptokeys(domain_id);
CREATE TABLE tsigkeys (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255),
    algorithm   VARCHAR(50),
    secret      VARCHAR(255)
);
CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
SQL
  else
    log_info "Esquema PowerDNS ya presente (dominio 'domains' existe)."
  fi
}

main() {
  if [[ "${DB_TYPE}" == "mysql" ]]; then
    log_error "Soporte MySQL no implementado en este paso. Cambia DB_TYPE=postgresql o extiende el script."
    exit 20
  fi

  systemctl is-active --quiet postgresql || log_cmd systemctl start postgresql

  # Generar contraseña si falta
  if [[ -z "${DB_PASSWORD}" ]]; then
    DB_PASSWORD=$(generate_password)
    export DB_PASSWORD
    log_info "Generada contraseña de BD para ${DB_USER} (oculta en logs)."
  fi

  # Crear usuario y base de datos idempotentemente
  local exists
  exists=$(psql_exec "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'") || true
  if [[ "$exists" != "1" ]]; then
    log_info "Creando rol ${DB_USER}"
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';"
  else
    log_info "Rol ${DB_USER} ya existe, sincronizando contraseña"
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
  fi

  exists=$(psql_exec "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'") || true
  if [[ "$exists" != "1" ]]; then
    log_info "Creando base de datos ${DB_NAME}"
    sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}"
  else
    log_info "Base de datos ${DB_NAME} ya existe"
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};"
  fi

  # Privilegios
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" -c "ALTER SCHEMA public OWNER TO ${DB_USER};"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};"

  # Aplicar esquema PowerDNS
  apply_pdns_schema_pg

  # Ajustar pg_hba para conexiones locales con scram
  local hba="/etc/postgresql/16/main/pg_hba.conf"
  if [[ -f "$hba" ]]; then
    if ! grep -qE "^host\s+${DB_NAME}\s+${DB_USER}\s+127\.0\.0\.1/32\s+scram-sha-256" "$hba"; then
      echo "host    ${DB_NAME}    ${DB_USER}    127.0.0.1/32    scram-sha-256" | sudo tee -a "$hba" >/dev/null
      log_cmd systemctl reload postgresql || true
    fi
  fi

  log_info "Base de datos configurada satisfactoriamente."
}

main "$@"
