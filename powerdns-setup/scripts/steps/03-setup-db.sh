#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 3: Configuración de base de datos ($DB_TYPE)"

mkdir -p "$INSTALL_DIR" 2>/dev/null || true

# Generate password if empty
if [ -z "${DB_PASSWORD:-}" ]; then
  DB_PASSWORD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9!@#%^&*()_+=' | head -c 24)
  export DB_PASSWORD
  log_warn "DB_PASSWORD no definido. Se generó automáticamente (oculto en logs)."
fi

case "$DB_TYPE" in
  postgresql)
    if command -v psql >/dev/null 2>&1; then
      log_info "PostgreSQL ya instalado"
    else
      run_cmd apt-get install -y postgresql postgresql-contrib
    fi
    # Ensure service
    run_cmd systemctl enable postgresql
    run_cmd systemctl start postgresql

    # Asegurar creación/actualización del rol y de la base de datos de forma idempotente y robusta
    # Escapar comillas simples del password por seguridad
    pw_esc=${DB_PASSWORD//"'"/"''"}

    # Crear/actualizar rol con LOGIN y password; si existe, solamente actualiza el password
    run_cmd sudo -u postgres psql -v ON_ERROR_STOP=1 -c "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER') THEN CREATE ROLE \"$DB_USER\" LOGIN PASSWORD '$pw_esc'; ELSE ALTER ROLE \"$DB_USER\" LOGIN PASSWORD '$pw_esc'; END IF; END $$;"

    # Verificar existencia de la base de datos y crear si falta
    set +e
    pg_db_exists=$(sudo -u postgres psql -Atc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';" 2>/dev/null)
    pg_db_rc=$?
    set -e
    if [ $pg_db_rc -ne 0 ]; then
      log_warn "No se pudo verificar existencia de la base de datos en PostgreSQL (rc=$pg_db_rc). Intentando crearla igualmente."
      run_cmd sudo -u postgres createdb "$DB_NAME" || true
    else
      if [ "$pg_db_exists" = "1" ]; then
        log_info "Base de datos '$DB_NAME' ya existe"
      else
        run_cmd sudo -u postgres createdb "$DB_NAME"
      fi
    fi

    # Asegurar que el owner de la BD sea el usuario configurado
    run_cmd sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";" || true

    # Conceder privilegios (idempotente)
    run_cmd sudo -u postgres psql -v ON_ERROR_STOP=1 -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";" || true
    # Conceder sobre esquema public (comúnmente requerido)
    run_cmd sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";" || true
    ;;
  mysql|mariadb)
    if command -v mysql >/dev/null 2>&1; then
      log_info "MySQL/MariaDB ya instalado"
    else
      run_cmd apt-get install -y mariadb-server
    fi
    run_cmd systemctl enable mariadb
    run_cmd systemctl start mariadb
    run_cmd mysql -uroot -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
    run_cmd mysql -uroot -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';"
    run_cmd mysql -uroot -e "GRANT ALL ON \`$DB_NAME\`.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;"
    ;;
  *)
    log_error "DB_TYPE no soportado: $DB_TYPE"
    exit 10
    ;;
 esac

# Save masked credentials
cat > "$INSTALL_DIR/CREDENTIALS.txt" <<EOF
[Base de Datos]
Tipo: $DB_TYPE
Nombre: $DB_NAME
Usuario: $DB_USER
Contraseña: $DB_PASSWORD
EOF
chmod 600 "$INSTALL_DIR/CREDENTIALS.txt" 2>/dev/null || true

log_success "Base de datos configurada"
