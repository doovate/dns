#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env
require_root

info "Configurando base de datos (${DB_ENGINE})"

if [[ "$DB_ENGINE" == "POSTGRES" ]]; then
  systemctl enable --now postgresql || true

  # Create users and DBs idempotently
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${PDNS_DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER \"${PDNS_DB_USER}\" WITH PASSWORD '${PDNS_DB_PASS}';"

  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${PDNS_DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE \"${PDNS_DB_NAME}\" OWNER \"${PDNS_DB_USER}\";"

  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${PDNSADMIN_DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER \"${PDNSADMIN_DB_USER}\" WITH PASSWORD '${PDNSADMIN_DB_PASS}';"

  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${PDNSADMIN_DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE \"${PDNSADMIN_DB_NAME}\" OWNER \"${PDNSADMIN_DB_USER}\";"

  # Grant extensions helpful
  sudo -u postgres psql -d "${PDNS_DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" || true
  sudo -u postgres psql -d "${PDNSADMIN_DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" || true

  success "Base de datos PostgreSQL lista"
else
  error "Motor ${DB_ENGINE} no soportado aún en este instalador"; exit 1
fi
