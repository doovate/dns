# Solución de problemas (PowerDNS Setup)

## apt: Unable to locate package / paquetes no encontrados
Causas:
- Lista de paquetes desactualizada
- Repositorios faltantes
Acciones:
- Ejecuta `apt update`
- Verifica conectividad a Internet (paso 1)
- Reintenta el paso desde el instalador

## MariaDB no inicia
Causas:
- Configuración corrupta o falta de espacio
Acciones:
- `journalctl -u mariadb -xe`
- Verifica espacio en disco (paso 1)
- `systemctl restart mariadb`

## Esquema PowerDNS no encontrado
Síntoma: `/usr/share/pdns-backend-mysql/schema/schema.mysql.sql` no existe
Acciones:
- Reinstala `pdns-backend-mysql`
- Verifica la ruta: `dpkg -L pdns-backend-mysql | grep schema`

## Puertos ocupados (53/5300/443)
Causas:
- systemd-resolved escuchando en 53
- Otro servicio usando 443 o 5300
Acciones:
- El paso 4 deshabilita systemd-resolved automáticamente
- `ss -lntup | grep -E ':53|:5300|:443'`
- Cambia puertos en `config.env` si es necesario

## Recursor no resuelve dominios externos
Causas:
- Forwarders no accesibles
- Firewall bloqueando
Acciones:
- Verifica `recursor.conf` (forward-zones-recurse)
- `ufw status`

## PowerDNS-Admin: errores con Python 3.12
Causas:
- Uso de virtualenv/distutils (obsoleto)
Acciones correctas:
- Instalar `python3-venv python3-pip`
- Crear venv: `python3 -m venv flask`
- Activar: `source flask/bin/activate`
- Actualizar: `pip install --upgrade pip setuptools wheel`

## Fallo al compilar dependencias Python
Causas:
- Faltan headers/compilador
Acciones:
- Asegura `python3-dev gcc libffi-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev pkg-config`

## Nginx no arranca / SSL
- `nginx -t` para validar configuración
- Certificado self-signed se genera en `/etc/nginx/ssl/`

## Reintentos y recuperación
El instalador mostrará el error completo y permite:
- Reintentar el paso
- Saltarlo (no recomendado)
- Abortar y reanudar luego con `--resume`

## Logs y estado
- Log general: `/var/log/powerdns-setup.log`
- Estado: `.install_progress`

