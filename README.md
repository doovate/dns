PowerDNS Automated Installer (Debian/Ubuntu)

This repository includes a helper script to install and configure PowerDNS (Authoritative), with optional Recursor, dnsdist, and the PowerDNS-Admin frontend. It follows the step-by-step procedure described in the issue, automating it safely and reproducibly.

What it does
- Adds the official PowerDNS APT repositories and pins them.
- Installs and configures your selected database backend (PostgreSQL by default or MariaDB/MySQL).
- Creates the pdns database, user, and credentials, and stores them in /opt/pdns_install/db_credentials.
- Installs pdns-server plus the backend driver (pgsql or mysql).
- Optionally installs pdns-recursor and dnsdist.
- Enables PowerDNS HTTP API and webserver, generates an API key, and restricts access by CIDR.
- Optionally installs PowerDNS-Admin (frontend) with Nginx + Gunicorn + systemd units.

Quick start
1) Use a fresh Debian/Ubuntu server VM. Ensure you can SSH and run sudo.
2) Copy this repository to the VM and run the installer with root privileges.

Example commands
- PostgreSQL backend (recommended), just the authoritative server:
  sudo bash scripts/install_powerdns.sh --db pgsql --non-interactive

- PostgreSQL + Recursor + dnsdist, with your external IP and LAN CIDR:
  sudo bash scripts/install_powerdns.sh --db pgsql --with-recursor --with-dnsdist \
      --external-ip 203.0.113.10 --lan-cidr 192.168.1.0/24 --non-interactive

- MariaDB backend and PowerDNS-Admin UI:
  sudo bash scripts/install_powerdns.sh --db mysql --with-admin --non-interactive

Flags
- --db [pgsql|mysql]    Choose the backend (default: pgsql)
- --with-recursor       Also install pdns-recursor
- --with-dnsdist        Also install dnsdist (requires --external-ip)
- --with-admin          Install PowerDNS-Admin (frontend)
- --external-ip <IP>    Your server's external IP used in examples/configs
- --lan-cidr <CIDR>     Allowed CIDR for PDNS API (default: 127.0.0.1/32)
- --non-interactive     Do not prompt; assume yes for safe defaults
- --dry-run             Print what would be done, without making changes

Outputs and important files
- Credentials and variables are stored in: /opt/pdns_install/db_credentials
  Includes: pdns_db, pdns_db_user, pdns_pwd, pdnsadmin_salt, pdns_apikey, db_type
- PowerDNS config: /etc/powerdns/pdns.conf
- Backend config: /etc/powerdns/pdns.d/g<db>.conf (gpgsql.conf or gmysql.conf)
- Recursor config: /etc/powerdns/recursor.conf
- dnsdist config (if installed): /etc/dnsdist/dnsdist.conf
- PowerDNS-Admin root (if installed): /var/www/html/pdns

Service management
- Check status:
  systemctl status pdns
  systemctl status pdns-recursor   # if installed
  systemctl status dnsdist         # if installed
  systemctl status pdnsadmin.service pdnsadmin.socket  # if installed

- Restart:
  sudo systemctl restart pdns
  sudo systemctl restart pdns-recursor
  sudo systemctl restart dnsdist
  sudo systemctl restart nginx

Accessing the API and UI
- PDNS API URL: http://localhost:8081 (API enabled, api-key stored in /opt/pdns_install/db_credentials)
- PowerDNS-Admin UI (if installed): http://<server-ip>/

Notes
- The installer may stop systemd-resolved if you accept the prompt (or use --non-interactive). Set a valid nameserver in /etc/resolv.conf if needed.
- For PostgreSQL, consider changing local auth in pg_hba.conf to md5 or scram-sha-256 if your distro defaults to peer.
- Ensure your firewall allows DNS (53/tcp and 53/udp) and HTTP if you installed the UI.

Troubleshooting
- Repository/keys issues: Ensure the server has internet access and correct time (timedatectl status). Try rerunning with --dry-run first to see steps.
- Database connection errors from PDNS:
  - Verify /etc/powerdns/pdns.d/g<db>.conf has the correct user/password.
  - Check service logs: journalctl -u pdns -b
- PowerDNS-Admin build issues:
  - Confirm Node.js 20 and yarn installed.
  - Re-run the build phase: source /var/www/html/pdns/flask/bin/activate && cd /var/www/html/pdns && yarn install --pure-lockfile && flask assets build

Security considerations
- The generated credentials are stored root-readable only (0640). Rotate secrets as needed.
- Limit PDNS API access with webserver-allow-from CIDR list.

Spanish (Español)

Instalador Automático de PowerDNS (Debian/Ubuntu)

Este repo incluye un script para instalar y configurar PowerDNS (Autoritativo), con opciones para Recursor, dnsdist y el frontend PowerDNS-Admin. Automatiza los pasos del documento original.

Pasos rápidos
1) Use una VM Debian/Ubuntu con sudo.
2) Copie este repo a la VM y ejecute el instalador como root:
   sudo bash scripts/install_powerdns.sh --db pgsql --non-interactive

Ejemplos
- PostgreSQL + Recursor + dnsdist:
  sudo bash scripts/install_powerdns.sh --db pgsql --with-recursor --with-dnsdist \
      --external-ip 203.0.113.10 --lan-cidr 192.168.1.0/24 --non-interactive

- MariaDB + UI PowerDNS-Admin:
  sudo bash scripts/install_powerdns.sh --db mysql --with-admin --non-interactive

Estados/Servicios
- pdns (autoritativo): systemctl status pdns
- recursor: systemctl status pdns-recursor
- dnsdist: systemctl status dnsdist
- UI: systemctl status pdnsadmin.service pdnsadmin.socket

Credenciales y API
- Archivo: /opt/pdns_install/db_credentials
- API PDNS: http://localhost:8081 (api-key en el archivo de credenciales)

Problemas comunes
- DNS/Repos: verifique conectividad y hora del sistema.
- Errores DB: revise /etc/powerdns/pdns.d/g<db>.conf y logs con journalctl -u pdns -b
- UI: asegure Node 20 y yarn; reconstruya assets si falla.

Soporte
Si necesitas que lo ejecutemos juntos, comparte tu distribución (lsb_release -a), IP externa y el CIDR de tu LAN.
