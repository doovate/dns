# PowerDNS Professional Stack (Ubuntu 24.04)

Este proyecto automatiza la instalación de un stack profesional de PowerDNS:
- PowerDNS Recursor (puerto 53)
- PowerDNS Authoritative (puerto 5300)
- PowerDNS-Admin (GUI) detrás de Nginx con SSL
- Base de datos PostgreSQL

Todo se controla mediante un archivo central de configuración: `config.env`.

## Componentes
- ACLs limitadas a 192.168.24.0/22 y 10.66.66.0/24.
- Forwarding público a 8.8.8.8 y 1.1.1.1.
- Zonas internas servidas por Authoritative y consultadas vía Recursor.
- PowerDNS-Admin disponible vía HTTPS.

## Inicio rápido
1. Edite `config.env` según su entorno.
2. Ejecute la instalación:
   sudo bash install.sh
3. Verifique:
   - scripts/healthcheck.sh
   - scripts/test-dns.sh
4. Acceda a https://dns.doovate.com (o el FQDN configurado).

## Seguridad
- UFW habilitado por defecto.
- Rate limiting básico en Nginx (configurable).
- Contraseñas en `config.env`; cámbielas por valores fuertes antes de producción.

## Operación
- Backup: scripts/backup.sh
- Restore: scripts/restore.sh
- Desinstalar: scripts/uninstall.sh
- Healthcheck: scripts/healthcheck.sh

Consulte `INSTALL.md` y `USAGE.md` para detalles.
