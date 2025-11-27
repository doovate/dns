#!/usr/bin/env bash
set -Eeuo pipefail

# Paso 02: Instalación de dependencias
# - apt update
# - paquetes base

source "$REPO_ROOT/scripts/lib/logging.sh"

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

main() {
  log_info "Actualizando índices de paquetes..."
  log_cmd apt-get update -y

  local base_pkgs=(
    ca-certificates curl gnupg2 jq git lsb-release
    build-essential pkg-config 
    python3 python3-venv python3-pip python3-dev python3-setuptools
    libffi-dev libssl-dev libldap2-dev libsasl2-dev
    postgresql postgresql-contrib 
    pdns-server pdns-backend-pgsql pdns-recursor
    nginx openssl ufw iputils-ping net-tools iproute2
  )

  if [[ "${DB_TYPE}" == "mysql" ]]; then
    base_pkgs+=(mysql-server default-libmysqlclient-dev)
  else
    base_pkgs+=(libpq-dev)
  fi

  log_info "Instalando paquetes base..."
  log_cmd apt-get install -y "${base_pkgs[@]}"

  # Validar herramientas críticas
  for b in psql pdns_server pdns_recursor nginx openssl; do
    if ! ensure_cmd "$b"; then
      log_error "Comando requerido no encontrado: $b"
      exit 10
    fi
  done

  log_info "Dependencias instaladas correctamente."
}

main "$@"
