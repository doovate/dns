# Solución de problemas

## Fallo en Verificación del sistema
- Asegúrate de ejecutar como root/sudo.
- Verifica que estás en Ubuntu 24.04: `lsb_release -a`.
- Revisa conectividad: `ping 8.8.8.8`.
- Verifica espacio en disco: `df -h /`.

## Puertos en uso
- Identifica el proceso: `ss -lntp | grep :53`.
- Cambia los puertos en `config.env` o libera el puerto.

## Error instalando paquetes
- Ejecuta `apt-get update` y reintenta.
- Verifica proxies o restricciones de red.

## PowerDNS no inicia
- Revisa `/etc/powerdns/pdns.conf` y logs: `journalctl -u pdns -e`.
- Asegúrate de que la cadena de conexión (DSN) apunta a la BD correcta.

## Recursor no responde
- Comprueba `/etc/powerdns/recursor.conf` y `journalctl -u pdns-recursor -e`.
- Verifica `allow-from` contenga tus redes internas y VPN.

## Zona no resuelve
- `pdnsutil list-all-zones` para ver si la zona existe.
- `pdnsutil list-zone <zona>` para ver registros.
- Asegúrate de que el Recursor tiene `forward-zones=<zona>=127.0.0.1:<puerto_auth>`.

## PowerDNS-Admin no carga
- Revisa `systemctl status powerdns-admin` y el log del servicio.
- Verifica `.env` en `/opt/powerdns-admin`.
- Comprueba que Nginx está en marcha y el certificado válido (autofirmado).

## No puedo acceder a la WebUI
- Verifica UFW: `ufw status numbered`.
- Confirma que tu IP pertenece a `INTERNAL_NETWORK` o `VPN_NETWORK`.
- Revisa que `WEBUI_PORT` está abierto en UFW.

## Cambiar credenciales
- Puedes editar `config.env` y re-ejecutar los pasos relevantes.
- Vuelve a generar CREDENTIALS con el paso 10.

## Obtener más detalles
- Ejecuta `sudo bash install.sh --verbose` y revisa el log en `/var/log/powerdns-setup.log`.
