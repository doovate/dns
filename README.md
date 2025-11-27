Sistema de instalación automatizada de PowerDNS para Ubuntu 24.04 LTS

Este proyecto proporciona un script de instalación integral para desplegar un stack completo de DNS interno basado en PowerDNS en Ubuntu 24.04 LTS, cumpliendo los requisitos descritos:

- PowerDNS Authoritative escuchando en puerto 5300 (sirve zonas internas)
- PowerDNS Recursor escuchando en puerto 53 (recibe todas las consultas)
- PowerDNS-Admin como interfaz web de administración
- Base de datos MariaDB/MySQL
- Forwarding público a 8.8.8.8 y 1.1.1.1
- Nginx como reverse proxy con SSL (Certbot opcional)

Parámetros por defecto del entorno objetivo (modificables):
- IP del servidor DNS: 192.168.25.60
- Red interna: 192.168.24.0/22
- Red VPN WireGuard: 10.66.66.0/24
- Zona DNS interna: doovate.com

Estructura
- scripts/install_powerdns.sh: Instalador automatizado. Ejecutarlo en un servidor Ubuntu 24.04 LTS limpio.
- config/nginx/powerdns-admin.conf: Plantilla de host virtual Nginx para PowerDNS-Admin.
- config/systemd/powerdns-admin.service: Servicio systemd para ejecutar PowerDNS-Admin con gunicorn.
- config/pdns/pdns.local.gmysql.conf: Plantilla de backend MySQL para PowerDNS Authoritative.
- config/recursor/recursor.conf.template: Plantilla base de Recursor.

Uso rápido
1) Copiar el repo al servidor Ubuntu 24.04 (o solo el script):
   - scp -r ./ scripts/install_powerdns.sh usuario@IP:/tmp/
2) Conectarse al servidor e instalar como root o con sudo:
   - sudo bash /tmp/install_powerdns.sh \
       --db-password 'cambiaEstaClave' \
       --domain doovate.com \
       --dns-ip 192.168.25.60 \
       --internal-cidr 192.168.24.0/22 \
       --vpn-cidr 10.66.66.0/24 \
       --admin-fqdn powerdns.doovate.com \
       --enable-certbot

   Notas:
   - --admin-fqdn es el FQDN público o interno para acceder a PowerDNS-Admin vía Nginx.
   - --enable-certbot intentará emitir y configurar un certificado SSL con Certbot + Nginx.
   - Si omites parámetros, se usarán los valores por defecto definidos en el script.

Qué hace el instalador
- Instala MariaDB y prepara la base de datos "powerdns" con usuario "powerdns".
- Instala PowerDNS Authoritative, lo configura en el puerto 5300 con backend MySQL y API.
- Instala PowerDNS Recursor en el puerto 53, con ACLs para 192.168.24.0/22, 10.66.66.0/24 y localhost, y con:
  - Forward de la(s) zona(s) internas (doovate.com y reversas) hacia el Authoritative en 127.0.0.1:5300.
  - Forward recursivo público para el resto de dominios a 8.8.8.8 y 1.1.1.1.
- Instala PowerDNS-Admin bajo /opt/web/powerdns-admin en un virtualenv, aplica migraciones y construye assets.
- Crea un servicio systemd powerdns-admin.service (gunicorn en 127.0.0.1:8000).
- Configura Nginx como reverse proxy con el site de PowerDNS-Admin y, opcionalmente, emite certificado con Certbot.
- Ajusta resolv.conf de forma segura para evitar conflictos con systemd-resolved.
- Abre puertos en UFW si está activo (53/UDP,TCP; 80 y 443/TCP).

Acceso
- PowerDNS-Admin: https://<admin-fqdn>/ (o http si no activaste certbot). Primer usuario se crea vía interfaz web.
- API de PowerDNS Authoritative: http://127.0.0.1:8081/ (API key generada en el script, se configura en PowerDNS-Admin).

Notas importantes
- Ejecuta en Ubuntu 24.04 LTS limpio para minimizar conflictos.
- El instalador deshabilita systemd-resolved y gestiona /etc/resolv.conf durante la instalación. Al finalizar, dejará 127.0.0.1 para que el propio recursor resuelva.
- Cambia la contraseña de la base de datos y la API key por valores seguros.
- Revisa los ficheros generados:
  - /etc/powerdns/pdns.conf, /etc/powerdns/pdns.d/pdns.local.gmysql.conf
  - /etc/powerdns/recursor.conf
  - /etc/nginx/sites-available/powerdns-admin (y el symlink en sites-enabled)
  - /etc/systemd/system/powerdns-admin.service

Desinstalación rápida (manual)
- systemctl disable --now powerdns-admin pdns pdns-recursor nginx
- apt purge -y pdns-server pdns-backend-mysql pdns-recursor mariadb-server nginx certbot
- rm -rf /opt/web/powerdns-admin /etc/powerdns /etc/nginx/sites-available/powerdns-admin /etc/nginx/sites-enabled/powerdns-admin
- Eliminar DB y usuario en MariaDB si procede.

Basado en la guía: "How to Install PowerDNS on Ubuntu 24.04" (adaptado y extendido para la arquitectura solicitada).

Configuración centralizada (un solo archivo)
- Para no tener parámetros repartidos, ahora puedes definir TODA la configuración en un único archivo .env.
- Archivo de ejemplo: config/powerdns.env (edítalo con tus valores).
- Precedencia al ejecutar scripts/install_powerdns.sh:
  1) powerdns.env en el directorio actual
  2) config/powerdns.env del repositorio
  3) /etc/powerdns-installer/powerdns.env (persistido tras la instalación)
  4) Flags por línea de comandos (tienen mayor prioridad que el .env)

Uso con archivo de configuración
- Edita config/powerdns.env y luego ejecuta:
  sudo bash scripts/install_powerdns.sh
- O bien, coloca un powerdns.env junto al script y ejecútalo desde allí.

Persistencia automática
- Tras una instalación exitosa, el script escribe la configuración efectiva en:
  /etc/powerdns-installer/powerdns.env
- Así tendrás SIEMPRE un único archivo del sistema donde consultar y ajustar los parámetros clave.
- Puedes re-ejecutar el instalador para aplicar cambios futuros, usando ese archivo.

Parámetros disponibles en el .env
- DB_NAME, DB_USER, DB_PASS
- DOMAIN, DNS_IP, INTERNAL_CIDR, VPN_CIDR
- ADMIN_FQDN
- ENABLE_CERTBOT (true/false)
- API_KEY (opcional; si se deja vacío, se genera automáticamente)
