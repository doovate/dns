#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

_domain_exists(){
  mariadb -u "${DB_USER}" -p"${DB_PASSWORD}" -D "${DB_NAME}" -e "SELECT name FROM domains WHERE name='${DNS_ZONE}';" 2>/dev/null | grep -q "${DNS_ZONE}"
}

_record_exists(){
  local name="$1"; local type="$2"; local content="$3"
  mariadb -u "${DB_USER}" -p"${DB_PASSWORD}" -D "${DB_NAME}" -e "SELECT name FROM records WHERE name='${name}' AND type='${type}' AND content='${content}';" 2>/dev/null | grep -q "${name}"
}

main(){
  if ! _domain_exists; then
    log_info "Creando zona ${DNS_ZONE}..."
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e \"INSERT INTO domains (name, type) VALUES ('${DNS_ZONE}', 'NATIVE');\""
    # Obtener domain_id
    DOMAIN_ID=$(mariadb -N -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e "SELECT id FROM domains WHERE name='${DNS_ZONE}';")
    # SOA
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e \"INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (${DOMAIN_ID}, '${DNS_ZONE}', 'SOA', 'dns.${DNS_ZONE} admin.${DNS_ZONE} 1 10800 3600 604800 3600', 86400, 0);\""
    # NS
    run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e \"INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (${DOMAIN_ID}, '${DNS_ZONE}', 'NS', 'dns.${DNS_ZONE}', 86400, 0);\""
  else
    log_info "Zona ${DNS_ZONE} ya existe"
    DOMAIN_ID=$(mariadb -N -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e "SELECT id FROM domains WHERE name='${DNS_ZONE}';")
  fi

  # Registros del array DNS_RECORDS
  for entry in "${DNS_RECORDS[@]}"; do
    IFS=":" read -r host rtype rvalue <<< "$entry"
    local fqdn
    if [[ "$host" == "@" ]]; then fqdn="${DNS_ZONE}"; else fqdn="${host}.${DNS_ZONE}"; fi
    if _record_exists "$fqdn" "$rtype" "$rvalue"; then
      log_info "Registro ya existe: $fqdn $rtype $rvalue"
    else
      log_info "Creando registro: $fqdn $rtype $rvalue"
      run_or_recover "$STEP_TITLE" "$STEP_KEY" "mariadb -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e \"INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (${DOMAIN_ID}, '${fqdn}', '${rtype}', '${rvalue}', 3600, 0);\""
    fi
  done

  progress_set "$STEP_KEY" "completed"
}

main "$@"
