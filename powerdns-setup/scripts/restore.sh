#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env
require_root

ARCHIVE=${1:-}
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  error "Uso: $0 <ruta/backup.tgz>"; exit 1
fi

info "Restaurando desde $ARCHIVE"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

tar -xzf "$ARCHIVE" -C "$TMPDIR"

# Restore configs
if confirm "Restaurar configuraciones /etc? Esto sobrescribirá archivos"; then
  rsync -a "$TMPDIR/etc/" /etc/
  systemctl reload nginx || true
fi

# Restore PowerDNS-Admin config
if [[ -f "$TMPDIR/opt/config.py" ]]; then
  cp -a "$TMPDIR/opt/config.py" "$PDNSA_BASE_DIR/config.py"
fi

# Restore databases
if [[ "$DB_ENGINE" == "POSTGRES" ]]; then
  if confirm "Restaurar bases de datos PostgreSQL? (destructivo)"; then
    sudo -u postgres dropdb --if-exists "$PDNS_DB_NAME"
    sudo -u postgres createdb "$PDNS_DB_NAME" -O "$PDNS_DB_USER"
    sudo -u postgres pg_restore -d "$PDNS_DB_NAME" "$TMPDIR/pdns.dump"

    sudo -u postgres dropdb --if-exists "$PDNSADMIN_DB_NAME"
    sudo -u postgres createdb "$PDNSADMIN_DB_NAME" -O "$PDNSADMIN_DB_USER"
    sudo -u postgres pg_restore -d "$PDNSADMIN_DB_NAME" "$TMPDIR/pdnsadmin.dump"
  fi
fi

systemctl restart pdns || true
systemctl restart pdns-recursor || true
systemctl restart powerdns-admin || true

success "Restauración completada"
