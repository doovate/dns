# Uso de PowerDNS-Admin y utilidades

## Acceso web
- URL: https://<PDNSA_FQDN>
- Usuario inicial: PDNSA_ADMIN_USER (definido en config.env)
- Contraseña inicial: PDNSA_ADMIN_PASSWORD

Tras el primer login, cambie la contraseña y configure autenticación adicional si se requiere.

## Crear zona
1. Inicie sesión en PowerDNS-Admin.
2. Vaya a Domains -> Create Domain.
3. Cree la zona `doovate.com` si no existe o edite registros.
4. Use Records para añadir A/AAAA/CNAME/MX/etc.

## DNS desde clientes
- Configure a sus clientes para usar el servidor DNS `DNS_SERVER_IP`.
- Las consultas a dominios internos (`doovate.com`) se resuelven en el Authoritative.
- Los dominios públicos se reenvían a los forwarders configurados.

## Logs
- PowerDNS: journalctl -u pdns -u pdns-recursor
- Nginx: /var/log/nginx/pdns-admin.access.log, pdns-admin.error.log
- PowerDNS-Admin: revisar logs de gunicorn con journalctl -u powerdns-admin

## Comandos útiles
- Reiniciar servicios: sudo systemctl restart pdns pdns-recursor powerdns-admin nginx
- Ver estado: sudo systemctl status pdns pdns-recursor powerdns-admin nginx
- Probar DNS: scripts/test-dns.sh
- Healthcheck: scripts/healthcheck.sh
- Backup: scripts/backup.sh
- Restore: scripts/restore.sh <archivo>

## Seguridad
- Ajuste UFW según su red.
- Revise y limite accesos en Nginx si expone el GUI a Internet.
- Mantenga actualizado el sistema (unattended-upgrades recomendado).
