# Guía de instalación detallada

Esta guía describe los 12 pasos que ejecuta el instalador y las decisiones que puedes tomar.

## 0. Preparación
- Clona este repositorio en el servidor Ubuntu 24.04 (recomendado)
- Edita `config.env` y ajusta:
  - IP del servidor DNS, redes internas, zona, forwarders
  - Tipo de BD y credenciales si quieres definirlas tú
  - Puertos si existen conflictos

## 1. Verificación del sistema
- Revisa privilegios, SO, conectividad, espacio y puertos.
- Si algún puerto está ocupado, verás una advertencia.

## 2. Dependencias
- Instala paquetes básicos: curl, jq, git, python3, venv, pip, ufw, nginx, openssl, dnsutils, gettext, etc.

## 3. Base de datos
- Soporta PostgreSQL (por defecto) o MariaDB/MySQL.
- Crea DB y usuario si no existen.
- Genera contraseña si no la diste.

## 4. PowerDNS Authoritative
- Instala `pdns-server` y backends.
- Genera `/etc/powerdns/pdns.conf` desde plantilla.

## 5. PowerDNS Recursor
- Instala `pdns-recursor`.
- Genera `/etc/powerdns/recursor.conf` con forwarders y allow-from.

## 6. Zonas DNS
- Crea la zona `DNS_ZONE` si no existe.
- Añade registros A iniciales de `config.env`.

## 7. PowerDNS-Admin
- Clona el repositorio, crea venv, instala requirements.
- Genera `.env` con conexión a BD y PDNS API.
- Migra la base de datos y crea usuario admin si falta.
- Crea servicio systemd que levanta Flask en 127.0.0.1:9192.

## 8. nginx
- Genera certificado SSL autofirmado.
- Crea sitio reverse proxy en `WEBUI_PORT` hacia 127.0.0.1:9192.

## 9. Firewall (ufw)
- Policies restrictivas, abre 22/tcp (si usas SSH).
- Abre 53 tcp/udp solo para redes internas y VPN.
- Abre `WEBUI_PORT` solo para redes internas y VPN.

## 10. Credenciales
- Genera credenciales faltantes.
- Escribe `INSTALL_DIR/CREDENTIALS.txt` con chmod 600.

## 11. Servicios
- Habilita e inicia servicios (pdns, recursor, pda, nginx, bd).

## 12. Pruebas finales
- Pruebas de DNS, HTTP y API.

## Dry-run e interacción
- `--dry-run` imprime acciones sin ejecutarlas.
- `--non-interactive` no pide confirmaciones.
- `--no-resume` reinicia el progreso.

## Desinstalación
- `sudo bash uninstall.sh --purge-data` elimina el stack.

## Logs y diagnóstico
- Log principal: `LOG_FILE` (por defecto /var/log/powerdns-setup.log)
- `scripts/healthcheck.sh` valida servicios y puertos.
- `scripts/test-dns.sh` corre consultas básicas a la zona.
