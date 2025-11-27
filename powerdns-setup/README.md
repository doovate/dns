# PowerDNS Setup para Ubuntu 24.04 LTS

Instalador interactivo, reanudable y con control total para desplegar:
- PowerDNS Authoritative (puerto 5300)
- PowerDNS Recursor (puerto 53)
- PowerDNS-Admin (web UI) detrás de Nginx con SSL
- Backend de base de datos: MariaDB (MySQL)

Incluye: archivo de progreso, modo automático, dry-run, manejo robusto de errores, e instalación compatible con Python 3.12 (sin distutils, usando venv).

## Requisitos
- Ubuntu 24.04 LTS
- Acceso root (sudo)
- Conectividad a Internet

## Estructura
```
powerdns-setup/
├── install.sh
├── uninstall.sh (pendiente)
├── config.env
├── .install_progress (auto)
├── CREDENTIALS.txt (auto)
├── configs/
│   ├── pdns.conf.template
│   ├── pdns.local.gmysql.conf.template
│   ├── recursor.conf.template
│   └── nginx-powerdns.conf.template
└── scripts/
    ├── lib/
    │   ├── colors.sh
    │   ├── logging.sh
    │   ├── progress.sh
    │   └── errors.sh
    └── steps/
        ├── 01-system-check.sh
        ├── 02-install-deps.sh
        ├── 03-setup-db.sh
        ├── 04-install-pdns-auth.sh
        ├── 05-install-pdns-recursor.sh
        ├── 06-configure-zones.sh
        ├── 07-install-pdns-admin.sh
        ├── 08-setup-nginx.sh
        ├── 09-setup-firewall.sh
        ├── 10-generate-creds.sh
        ├── 11-start-services.sh
        └── 12-final-tests.sh
```

## Uso

Editar parámetros en config.env (IP, zona, puertos, etc). Valores por defecto:
- DNS_SERVER_IP=192.168.25.60
- INTERNAL_NETWORK=192.168.24.0/22
- VPN_NETWORK=10.66.66.0/24
- DNS_ZONE=doovate.com
- Forwarders: 8.8.8.8 y 1.1.1.1

### Ejecutar
Modo interactivo por defecto:
```
sudo bash install.sh
```

Opciones:
```
sudo bash install.sh --auto     # sin pausas
sudo bash install.sh --reset    # borra .install_progress
sudo bash install.sh --resume   # continúa donde se quedó
sudo bash install.sh --dry-run  # no realiza cambios
```

El instalador:
- Presenta cada paso y lo valida
- Comprueba si ya está hecho y evita repetir
- Guarda el estado en .install_progress
- Muestra errores completos y permite reintentar/saltar/abortar

## Notas sobre Python 3.12
Ubuntu 24.04 usa Python 3.12 sin distutils. Este proyecto usa:
- python3-venv (no virtualenv)
- python3-pip, python3-dev
- Creación del entorno: `python3 -m venv flask`
- Actualización dentro del venv: `pip install --upgrade pip setuptools wheel`

## Pruebas finales automáticas
El paso 12 realiza:
- Estado de servicios (pdns, pdns-recursor, powerdns-admin, nginx)
- Resolución interna y externa
- Estado HTTP de la Web UI

## Desinstalación
Pendiente: `uninstall.sh` eliminará servicios, paquetes y configuración (no borrará la base de datos por seguridad, a menos que se use `--purge`).

## Seguridad
- Contraseñas generadas con openssl (20+ chars)
- UFW restrictivo (opcional)
- Certificado self-signed por defecto (Let’s Encrypt puede añadirse)
- CREDENTIALS.txt con permisos 600

## Soporte
Si algún paso falla, consulta `logs` en `/var/log/powerdns-setup.log` y el archivo `.install_progress`. Reejecuta con `--resume` tras corregir.
