# Uso básico de PowerDNS-Admin

## Acceso
- URL: https://<DNS_SERVER_IP>:<WEBUI_PORT>
- Usuario: ver CREDENTIALS.txt (por defecto admin)
- Contraseña: ver CREDENTIALS.txt

Acepta la advertencia del navegador por certificado autofirmado.

## Crear zona
1. Inicie sesión en PowerDNS-Admin.
2. Vaya a Domains -> Add Domain.
3. Seleccione Native Zone e ingrese `doovate.com` (o la definida en DNS_ZONE).
4. Guarde.

El instalador ya crea la zona y registros de ejemplo si no existen.

## Añadir registros
1. Entre a la zona `doovate.com`.
2. Add Record -> Tipo A -> Nombre `host` -> Valor `IP` -> TTL 3600.
3. Guarde y aplique.

## Probar resolución
Desde el servidor:
```
sudo bash scripts/test-dns.sh
```

O manualmente:
```
dig +short @127.0.0.1 -p 53 dv-vpn.doovate.com A
```

## Mantenimiento
- Reiniciar servicios: `sudo systemctl restart pdns pdns-recursor powerdns-admin nginx`
- Ver estado: `sudo bash scripts/healthcheck.sh`
- Ver logs: `sudo journalctl -u pdns -e -f`
