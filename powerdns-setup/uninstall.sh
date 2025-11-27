#!/usr/bin/env bash
# Desinstalador básico de PowerDNS setup (no borra la base de datos salvo --purge)
set -euo pipefail

PURGE=false
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=true ;;
    -h|--help)
      echo "Uso: sudo bash uninstall.sh [--purge]"
      echo "--purge: elimina paquetes y archivos de configuración (la BD se elimina)"
      exit 0
      ;;
  esac
done

stop_disable(){
  systemctl disable --now "$1" 2>/dev/null || true
}

main(){
  stop_disable powerdns-admin
  stop_disable pdns-recursor
  stop_disable pdns
  stop_disable nginx
  stop_disable mariadb

  rm -f /etc/systemd/system/powerdns-admin.service || true
  systemctl daemon-reload || true

  # Configs
  rm -f /etc/powerdns/recursor.conf || true
  rm -rf /etc/powerdns/pdns.d || true

  # Nginx site
  rm -f /etc/nginx/sites-enabled/powerdns-admin || true
  rm -f /etc/nginx/sites-available/powerdns-admin || true
  rm -rf /etc/nginx/ssl || true
  systemctl restart nginx || true

  # Paquetes
  apt remove -y pdns-recursor pdns-server pdns-backend-mysql nginx yarn nodejs || true
  if [ "$PURGE" = true ]; then
    apt purge -y pdns-recursor pdns-server pdns-backend-mysql nginx || true
    # borrar base de datos y usuario
    mariadb -u root -e "DROP DATABASE IF EXISTS powerdns;" || true
    mariadb -u root -e "DROP USER IF EXISTS 'pdns'@'localhost'; FLUSH PRIVILEGES;" || true
  fi

  echo "Desinstalación completada."
}

main "$@"
