#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

main(){
  # Dependencias para compilar e integrar
  local pkgs=(python3-venv python3-pip python3-dev libpq-dev gcc libmysqlclient-dev libsasl2-dev libffi-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev pkg-config)
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y ${pkgs[*]}"

  # Node.js 18 y Yarn
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y nodejs"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnpkg-archive-keyring.gpg > /dev/null"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "bash -c 'echo "deb [signed-by=/usr/share/keyrings/yarnpkg-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list'"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt update"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y yarn"

  # Clonar PowerDNS-Admin si no existe
  if [ ! -d "$PDNS_ADMIN_PATH" ]; then
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mkdir -p $(dirname $PDNS_ADMIN_PATH)"
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git ${PDNS_ADMIN_PATH}"
  else
    log_info "Repositorio PowerDNS-Admin ya existe; actualizando..."
    (cd "$PDNS_ADMIN_PATH" && git pull --rebase) || true
  fi

  cd "$PDNS_ADMIN_PATH"

  # Crear entorno virtual con venv (Python 3.12 compatible)
  if [ ! -d "flask" ]; then
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "python3 -m venv flask"
  fi

  # Activar entorno
  # shellcheck disable=SC1091
  source "$PDNS_ADMIN_PATH/flask/bin/activate"

  # Actualizar pip/setuptools/wheel dentro del entorno
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "pip install --upgrade pip setuptools wheel"

  # Instalar dependencias de Python
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "pip install -r requirements.txt"

  # Configurar base de datos en default_config.py si no existe
  if [ ! -f powerdnsadmin/default_config.py ]; then
    cat > powerdnsadmin/default_config.py <<EOF
SQLA_DB_USER = '${DB_USER}'
SQLA_DB_PASSWORD = '${DB_PASSWORD}'
SQLA_DB_HOST = '${DB_HOST}'
SQLA_DB_NAME = '${DB_NAME}'
SQLALCHEMY_TRACK_MODIFICATIONS = True
EOF
  fi

  export FLASK_APP=powerdnsadmin/__init__.py
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "flask db upgrade"

  # Generar assets
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "yarn install --pure-lockfile"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "flask assets build"

  deactivate || true

  progress_set "$STEP_KEY" "completed"
}

main "$@"
