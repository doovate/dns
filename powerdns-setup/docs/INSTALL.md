# Guía de instalación

Requisitos: Ubuntu 24.04 LTS con acceso a Internet y privilegios sudo/root.

## 1. Configurar variables
Opcional: puede editar `config.env` para ajustar IPs, puertos, redes, forwarders y FQDN.
Notas importantes:
- Las contraseñas y claves (PDNS_DB_PASS, PDNSADMIN_DB_PASS, PDNSA_ADMIN_PASSWORD, PDNS_API_KEY) se generan automáticamente en el primer `install.sh` si están con valores por defecto o vacías.
- El instalador crea una copia de seguridad de `config.env` antes de modificarlo (`config.env.bak.<timestamp>`).
- Después de la instalación, guarde estas credenciales en un lugar seguro.

## 2. Ejecutar instalación
sudo bash install.sh

El script es idempotente. Puede ejecutarse múltiples veces.

## 3. Firewall
Por defecto se habilita UFW y se abren:
- UDP/TCP 53 (recursor)
- TCP 5300 (authoritative)
- TCP 80/443 (Nginx)
- TCP 9191 local (Gunicorn) sólo en loopback

## 4. Verificación
- scripts/healthcheck.sh
- scripts/test-dns.sh

## 5. Acceso web
Abra https://<PDNSA_FQDN> y acceda con:
- Usuario: PDNSA_ADMIN_USER
- Password: PDNSA_ADMIN_PASSWORD

## 6. Administración de zonas
- Las zonas se gestionan en PowerDNS-Admin.
- Cambios se aplican al backend de PowerDNS vía API.

## 7. Backup y restore
- scripts/backup.sh y scripts/restore.sh

## 8. Desinstalación
- scripts/uninstall.sh (con confirmaciones)

## Notas
- Para Let's Encrypt, ajuste ENABLE_LETSENCRYPT=true y asegure accesibilidad desde Internet al FQDN.
- Para cambiar a MySQL se requeriría ampliar los scripts. Actualmente se soporta PostgreSQL por estabilidad.
