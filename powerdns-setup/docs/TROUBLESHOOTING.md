# Troubleshooting

## Servicios no inician
- Ver estado: `sudo systemctl status pdns pdns-recursor powerdns-admin nginx`
- Revisar logs:
  - `journalctl -u pdns -e -f`
  - `journalctl -u pdns-recursor -e -f`
  - `journalctl -u powerdns-admin -e -f`
  - `journalctl -u nginx -e -f`

## WebUI no carga
- Verificar nginx: `sudo nginx -t` y `sudo systemctl restart nginx`
- Asegurarse de usar https://IP:PUERTO y aceptar certificado autofirmado
- Revisar firewall UFW (permitir WEBUI_PORT desde INTERNAL_NETWORK y VPN_NETWORK)

## DNS no responde
- Confirmar puertos abiertos: `sudo ss -ltnup | grep -E ':53 |:5300 '`
- Probar recursor local: `dig @127.0.0.1 -p 53 google.com A`
- Probar zona interna: `dig @127.0.0.1 -p 53 dv-vpn.doovate.com A`
- Revisar que recursor tenga `forward-zones` hacia 127.0.0.1:5300

## Error de base de datos
- Validar credenciales en `/etc/powerdns/pdns.conf` y `/opt/powerdns-admin/config.py`
- En PostgreSQL: `sudo -u postgres psql -c "\du"` y `\l` para ver usuarios y DBs
- En MySQL/MariaDB: `mysql -uroot -p -e "SHOW DATABASES;"`

## Registros no aparecen
- Forzar recarga: `sudo systemctl restart pdns pdns-recursor`
- Revisar caché de recursor (usar `dig +trace` o cambiar nombre temporalmente)

## Certificado SSL
- Si el navegador bloquea acceso, agregue excepción o instale un certificado válido.

## Otros
- Revise `CREDENTIALS.txt` para claves y URLs correctas.
- Vuelva a ejecutar el instalador; es idempotente: `sudo bash install.sh`
