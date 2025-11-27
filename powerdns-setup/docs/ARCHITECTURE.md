# Arquitectura del despliegue PowerDNS

Este proyecto despliega un stack de resolución DNS dividido en funciones y protegido por firewall.

## Componentes
- PowerDNS Authoritative (pdns-server): responde por zonas locales y sirve API/webserver interno (localhost:8081).
- PowerDNS Recursor (pdns-recursor): resuelve consultas recursivas, con forwarders públicos y reenvío a Authoritative para la zona interna.
- PowerDNS-Admin: interfaz web de administración, corre en 127.0.0.1:9192 (Flask), detrás de Nginx.
- Nginx: reverse proxy con TLS, expone la WebUI en `WEBUI_PORT` hacia clientes de redes internas.
- Base de datos (PostgreSQL o MariaDB): almacena datos de PowerDNS-Admin.
- UFW: firewall que limita exposición de servicios.

## Flujo de consultas DNS
1. Un cliente de la red interna o VPN envía una consulta a `DNS_SERVER_IP:53` (Recursor).
2. Si la consulta es para `DNS_ZONE` (por ejemplo, doovate.com), el Recursor reenvía a Authoritative en `127.0.0.1:PDNS_AUTH_PORT`.
3. Para dominios públicos, el Recursor usa forwarders configurados (`DNS_FORWARDER_1/2`).

## Seguridad y accesos
- UFW permite 53/tcp+udp desde `INTERNAL_NETWORK` y `VPN_NETWORK`.
- UFW permite `WEBUI_PORT` solo desde las redes internas/VPn.
- La WebUI corre detrás de Nginx con certificado SSL autofirmado.
- Credenciales se almacenan en `INSTALL_DIR/CREDENTIALS.txt` con chmod 600.
- Logs detallados se guardan en `LOG_FILE` con secretos ofuscados.

## Reanudación y estado
- `.install_progress` guarda los pasos completados para reanudar instalaciones interrumpidas.
- Cada paso verifica idempotencia antes de ejecutar cambios.

## Variables clave
- DNS_SERVER_IP, DNS_ZONE, INTERNAL_NETWORK, VPN_NETWORK
- PDNS_AUTH_PORT, PDNS_RECURSOR_PORT, WEBUI_PORT
- DB_TYPE, DB_NAME, DB_USER, DB_PASSWORD
- ADMIN_USERNAME, ADMIN_PASSWORD, ADMIN_EMAIL
- PDNS_API_KEY

## Systemd
- Servicios gestionados: pdns, pdns-recursor, powerdns-admin, nginx, y el motor de base de datos.
