# PowerDNS Setup Automático (Ubuntu 24.04 LTS)

Proyecto listo para desplegar un servidor DNS profesional con:
- PowerDNS Recursor (puerto 53)
- PowerDNS Authoritative (puerto 5300)
- PowerDNS-Admin (interfaz web)
- Base de datos PostgreSQL (por defecto; opcional MySQL)
- nginx con SSL (autofirmado)
- UFW (firewall)

Instalación 100% automatizada con un solo comando.

## Arquitectura

```
                +-----------------------------+
LAN/VPN Clients |  DNS Queries (UDP/TCP 53)   |
                +--------------+--------------+
                               |
                               v
                       [ PowerDNS Recursor ]  <-- 53/udp,tcp
                               |
                    +----------+----------+
                    |  Forwards public     |
                    |  to 8.8.8.8/1.1.1.1 |
                    v                     |
          [ PowerDNS Authoritative ]      |
                 127.0.0.1:5300           |
                 Serves doovate.com ------+

Web Admin:
Browser -> https://<DNS_SERVER_IP>:<WEBUI_PORT> -> nginx (SSL) -> PowerDNS-Admin (gunicorn)
```

## Requisitos previos
- Ubuntu 24.04 LTS
- Acceso root o sudo
- Conexión a Internet
- Recomendado: 1 vCPU, 1 GB RAM, 10 GB disco

## Instalación (rápida)

1) Descargar
```
cd /opt
sudo git clone <REPO_URL> powerdns-setup
cd powerdns-setup/powerdns-setup
```

2) (Opcional) Editar configuración
```
sudo nano config.env
```

3) Instalar
```
sudo bash install.sh
```

Al finalizar verás el resumen con URL de acceso y credenciales. Todas las credenciales se guardan en CREDENTIALS.txt (permisos 600) en la raíz del repo.

## Verificación
- Estado de servicios: `sudo bash scripts/healthcheck.sh`
- Pruebas DNS: `sudo bash scripts/test-dns.sh`
- Logs PDNS: `sudo tail -f /var/log/pdns/pdns.log`

## Desinstalación
```
sudo bash uninstall.sh
```

## Documentación
- INSTALL.md: Guía detallada paso a paso
- docs/USAGE.md: Uso básico de PowerDNS-Admin
- docs/TROUBLESHOOTING.md: Problemas comunes
- docs/ARCHITECTURE.md: Detalles de arquitectura
