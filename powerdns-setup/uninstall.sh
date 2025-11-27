#!/usr/bin/env bash
# Uninstall the PowerDNS stack (careful!)
set -euo pipefail

read -rp "This will remove PowerDNS, PowerDNS-Admin, nginx and optionally the database. Continue? (yes/NO): " ans
if [[ "${ans:-}" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

read -rp "Also drop the database and user? (yes/NO): " dropdb

systemctl stop powerdns-admin || true
systemctl stop pdns pdns-recursor nginx || true
systemctl disable powerdns-admin pdns pdns-recursor nginx || true

# Remove PowerDNS and nginx
apt-get remove -y pdns-server pdns-backend-pgsql pdns-recursor nginx || true
apt-get autoremove -y || true

# Remove PowerDNS-Admin files
rm -rf /opt/powerdns-admin || true
rm -f /etc/systemd/system/powerdns-admin.service || true
systemctl daemon-reload || true

# Optional: database cleanup (PostgreSQL)
if [[ "${dropdb:-}" == "yes" ]]; then
  if command -v psql >/dev/null 2>&1; then
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS powerdns;" || true
    sudo -u postgres psql -c "DROP ROLE IF EXISTS pdns;" || true
  fi
  if command -v mysql >/dev/null 2>&1; then
    mysql -uroot <<SQL
DROP DATABASE IF EXISTS powerdns;
DROP USER IF EXISTS 'pdns'@'localhost';
FLUSH PRIVILEGES;
SQL
  fi
fi

# Remove nginx SSL
rm -rf /etc/nginx/ssl || true

# Keep CREDENTIALS.txt and project files by default

echo "Uninstall complete. Some configuration files under /etc/powerdns may remain (backup your changes if needed)."