#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

# Comprueba si la BD ya existe
_db_exists(){
  mariadb -u root -e "SHOW DATABASES LIKE '${DB_NAME}';" 2>/dev/null | grep -q "${DB_NAME}" && return 0 || return 1
}

_user_exists(){
  mariadb -u root -e "SELECT User FROM mysql.user WHERE User='${DB_USER}' AND Host='localhost';" 2>/dev/null | grep -q "${DB_USER}" && return 0 || return 1
}

_schema_imported(){
  mariadb -u root -D "${DB_NAME}" -e "SHOW TABLES LIKE 'domains';" 2>/dev/null | grep -q domains
}

main(){
  # Instalar MariaDB y backend MySQL para PowerDNS
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y pdns-backend-mysql mariadb-server mariadb-client"

  # Asegurar que el servicio esté activo
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable mariadb"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl start mariadb"

  # Crear BD si no existe
  if ! _db_exists; then
    log_info "Creando base de datos ${DB_NAME}..."
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u root -e \"CREATE DATABASE IF NOT EXISTS ${DB_NAME};\""
  else
    log_info "Base de datos ${DB_NAME} ya existe"
  fi

  # Generar contraseña si está vacía
  if [ -z "${DB_PASSWORD}" ]; then
    DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    # Persistir en config.env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$ROOT_DIR/config.env"
    log_warn "Se generó una contraseña aleatoria para DB_USER. Guardada en config.env"
  fi

  # Crear usuario si no existe
  if ! _user_exists; then
    log_info "Creando usuario ${DB_USER}@localhost..."
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u root -e \"CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;\""
  else
    log_info "Usuario ${DB_USER}@localhost ya existe"
  fi

  # Importar esquema
  if ! _schema_imported; then
    local schema="/usr/share/pdns-backend-mysql/schema/schema.mysql.sql"
    if [ ! -f "$schema" ]; then
      log_error "No se encuentra el esquema de PowerDNS en $schema"
      return 1
    fi
    log_info "Importando esquema de PowerDNS..."
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u root ${DB_NAME} < $schema"
  else
    log_info "Esquema de PowerDNS ya importado"
  fi

  progress_set "$STEP_KEY" "completed"
}

main "$@"
