# Guía de Instalación Detallada

Esta guía describe los pasos para desplegar el stack de PowerDNS en Ubuntu 24.04 LTS.

## 1. Requisitos
- Ubuntu 24.04 LTS con acceso root/sudo
- Conexión a Internet
- Recursos mínimos: 1 vCPU, 1 GB RAM, 10 GB disco

## 2. Descargar el proyecto
```
cd /opt
sudo git clone <REPO_URL> powerdns-setup
cd powerdns-setup/powerdns-setup
```

## 3. (Opcional) Personalizar configuración
Edite `config.env` si desea cambiar IPs, puertos, zona DNS, tipo de base de datos o credenciales.
```
sudo nano config.env
```
Notas:
- Deje en blanco DB_PASSWORD y ADMIN_PASSWORD para generar contraseñas seguras automáticamente.
- DB_TYPE predeterminado es `postgresql`. También es compatible `mysql` (MariaDB).

## 4. Ejecutar instalación
```
sudo bash install.sh
```
El instalador:
- Verifica root, SO Ubuntu 24.04 e Internet
- Instala y configura PostgreSQL/MySQL
- Instala PowerDNS (Authoritative + Recursor)
- Instala PowerDNS-Admin (venv + gunicorn + systemd)
- Configura nginx con SSL autofirmado
- Configura firewall UFW (53 y WebUI desde redes internas)
- Crea la zona inicial y registros de ejemplo
- Genera y guarda CREDENTIALS.txt (permisos 600) en la raíz del repo

## 5. Acceder a la interfaz web
Use el navegador para abrir:
```
https://<DNS_SERVER_IP>:<WEBUI_PORT>
```
Usuario/contraseña y demás credenciales se encuentran en `CREDENTIALS.txt`.

## 6. Verificación rápida
```
sudo bash scripts/healthcheck.sh
sudo bash scripts/test-dns.sh
```

## 7. Desinstalación
```
sudo bash uninstall.sh
```
Sigue un asistente con confirmación. Puede optar por conservar o eliminar la base de datos.

## 8. Mantenimiento
- Reiniciar servicios: `sudo systemctl restart pdns pdns-recursor nginx powerdns-admin`
- Ver logs: `sudo journalctl -u <servicio> -e -f`
- Actualizar sistema: `sudo apt-get update && sudo apt-get -y upgrade`
