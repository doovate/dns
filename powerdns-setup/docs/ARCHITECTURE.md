# Arquitectura del Stack PowerDNS

Componentes principales:
- PowerDNS Authoritative (puerto 5300) – Sirve zonas internas (doovate.com)
- PowerDNS Recursor (puerto 53) – Recibe todas las consultas
- Base de datos (PostgreSQL por defecto, MySQL opcional)
- PowerDNS-Admin – Interfaz administrativa (Gunicorn en 127.0.0.1:9190)
- nginx – Reverse proxy SSL en WEBUI_PORT
- UFW – Firewall con reglas mínimas

## Flujo de consultas DNS
1. Cliente realiza consulta a 53/UDP/TCP -> Recursor.
2. Si la consulta pertenece a la zona interna (DNS_ZONE), recursor reenvía a Authoritative en 127.0.0.1:5300.
3. Si es pública, recursor reenvía a forwarders 8.8.8.8 y 1.1.1.1.

## Integración PowerDNS-Admin
- Se comunica con API de Authoritative en 127.0.0.1:8081 usando PDNS_API_KEY.
- Acceso web a través de nginx con TLS: https://DNS_SERVER_IP:WEBUI_PORT

## Seguridad
- Contraseñas y claves generadas automáticamente, longitud >= 16 chars.
- CREDENTIALS.txt con chmod 600 en la raíz del repo.
- nginx usa certificado autofirmado por defecto.
- UFW limita acceso a puertos 53/WEBUI a redes INTERNAL_NETWORK y VPN_NETWORK.

## Servicios y puertos
- pdns (authoritative): 5300/tcp
- pdns-recursor: 53/udp, 53/tcp
- PowerDNS-Admin (gunicorn): 9190/tcp (loopback)
- nginx: WEBUI_PORT/tcp (HTTPS)
- PDNS API: 8081/tcp (loopback)
