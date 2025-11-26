#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env
require_root

install -d "$BACKUP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE="$BACKUP_DIR/powerdns-backup-$STAMP.tgz"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

info "Creando backup en $ARCHIVE"

# Config files
mkdir -p "$TMPDIR/etc"
cp -a /etc/powerdns "$TMPDIR/etc/" 2>/dev/null || true
cp -a /etc/nginx/sites-available/pdns-admin.conf "$TMPDIR/etc/" 2>/dev/null || true
cp -a /etc/nginx/ssl "$TMPDIR/etc/" 2>/dev/null || true

# PowerDNS-Admin app config
mkdir -p "$TMPDIR/opt"
if [[ -f "$PDNSA_BASE_DIR/config.py" ]]; then cp -a "$PDNSA_BASE_DIR/config.py" "$TMPDIR/opt/"; fi

# Databases (PostgreSQL only)
if [[ "$DB_ENGINE" == "POSTGRES" ]]; then
  info "Volcando bases de datos PostgreSQL"
  sudo -u postgres pg_dump -Fc -d "$PDNS_DB_NAME" > "$TMPDIR/pdns.dump"
  sudo -u postgres pg_dump -Fc -d "$PDNSADMIN_DB_NAME" > "$TMPDIR/pdnsadmin.dump"
fi

# Systemd unit
cp -a /etc/systemd/system/powerdns-admin.service "$TMPDIR/" 2>/dev/null || true

# Create archive
tar -czf "$ARCHIVE" -C "$TMPDIR" .

success "Backup creado: $ARCHIVE"
