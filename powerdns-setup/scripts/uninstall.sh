#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env
require_root

warn "Este proceso eliminará servicios y configuraciones relacionadas con PowerDNS y PowerDNS-Admin."
if ! confirm "¿Desea continuar con la desinstalación?"; then
  info "Cancelado"; exit 0
fi

systemctl disable --now powerdns-admin || true
systemctl disable --now pdns || true
systemctl disable --now pdns-recursor || true

# Remove nginx site
rm -f /etc/nginx/sites-enabled/pdns-admin.conf /etc/nginx/sites-available/pdns-admin.conf || true
systemctl reload nginx || true

# Optionally remove app and configs
if confirm "¿Eliminar PowerDNS-Admin (/opt/powerdns-admin)?"; then
  rm -rf "$PDNSA_BASE_DIR"
fi
if confirm "¿Eliminar certificados SSL en /etc/nginx/ssl para ${PDNSA_FQDN}?"; then
  rm -f "/etc/nginx/ssl/${PDNSA_FQDN}.crt" "/etc/nginx/ssl/${PDNSA_FQDN}.key"
fi

if confirm "¿Eliminar configuración de /etc/powerdns?"; then
  rm -rf /etc/powerdns
fi

if confirm "¿Eliminar unidad systemd powerdns-admin.service?"; then
  rm -f /etc/systemd/system/powerdns-admin.service
  systemctl daemon-reload
fi

# Databases
if [[ "$DB_ENGINE" == "POSTGRES" ]]; then
  if confirm "¿Eliminar bases de datos y usuarios de PostgreSQL? (destructivo)"; then
    sudo -u postgres dropdb --if-exists "$PDNS_DB_NAME"
    sudo -u postgres dropdb --if-exists "$PDNSADMIN_DB_NAME"
    sudo -u postgres psql -c "DROP USER IF EXISTS \"${PDNS_DB_USER}\";"
    sudo -u postgres psql -c "DROP USER IF EXISTS \"${PDNSADMIN_DB_USER}\";"
  fi
fi

success "Desinstalación completada"
