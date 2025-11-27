#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

print_usage() {
  cat <<USAGE
Desinstalador PowerDNS - Opciones:
  --purge-data    Elimina datos (BD, zonas) además de paquetes
  --dry-run       Muestra lo que haría sin ejecutar cambios
  --help          Ayuda
USAGE
}
PURGE=false
DRY_RUN=false
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --purge-data) PURGE=true ;;
      --dry-run) DRY_RUN=true ;;
      --help|-h) print_usage; exit 0 ;;
      *) echo "Opción no reconocida: $1"; print_usage; exit 1 ;;
    esac
    shift
  done
}

main(){
  parse_arguments "$@"
  init_logging true "$LOG_FILE" true "$DRY_RUN"
  show_banner
  log_warn "Iniciando desinstalación"

  # Stop services
  for svc in powerdns-admin pdns-recursor pdns nginx postgresql mariadb; do
    systemctl list-unit-files | grep -q "^${svc}\.service" && run_cmd systemctl stop "$svc" || true
    systemctl list-unit-files | grep -q "^${svc}\.service" && run_cmd systemctl disable "$svc" || true
  done

  # Remove nginx site
  run_cmd rm -f /etc/nginx/sites-enabled/pdns-admin.conf /etc/nginx/sites-available/pdns-admin.conf || true
  run_cmd systemctl restart nginx || true

  # Remove PowerDNS-Admin app
  run_cmd rm -rf /opt/powerdns-admin || true
  run_cmd rm -f /etc/systemd/system/powerdns-admin.service && run_cmd systemctl daemon-reload || true

  # Optionally purge DB data
  if [ "$PURGE" = true ]; then
    case "$DB_TYPE" in
      postgresql)
        run_cmd sudo -u postgres psql -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" || true
        run_cmd sudo -u postgres psql -c "DROP USER IF EXISTS \"$DB_USER\";" || true
        ;;
      mysql|mariadb)
        run_cmd mysql -uroot -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" || true
        run_cmd mysql -uroot -e "DROP USER IF EXISTS '$DB_USER'@'%'; FLUSH PRIVILEGES;" || true
        ;;
    esac
  fi

  # Remove packages
  run_cmd apt-get remove -y pdns-server pdns-backend-pgsql pdns-backend-mysql pdns-recursor nginx ufw || true
  [ "$PURGE" = true ] && run_cmd apt-get purge -y postgresql mariadb-server || true

  # Cleanup configs
  run_cmd rm -f /etc/powerdns/pdns.conf /etc/powerdns/recursor.conf || true
  run_cmd rm -f /etc/nginx/pdns-admin.key /etc/nginx/pdns-admin.crt || true

  log_success "Desinstalación finalizada"
}

main "$@"
