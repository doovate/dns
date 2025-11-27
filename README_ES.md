Guía rápida para instalar PowerDNS en tu VM (Ubuntu 20.04)

Este repo contiene un script que automatiza la instalación de PowerDNS Autoritativo y, opcionalmente, el Recursor y la UI PowerDNS‑Admin.

Parámetros típicos para tu caso
- Distro: Ubuntu 20.04
- Backend DB: MySQL/MariaDB
- Componentes: Autoritativo + Recursor, sin dnsdist
- IP del servidor: 192.168.25.60
- Redes internas: 192.168.24.0/22 y 10.66.66.0/24
- Zona autoritativa: doovate.com
- DNS públicos de respaldo: 8.8.8.8 y 1.1.1.1

Comando sugerido (ejecutar como root o con sudo):

sudo bash scripts/install_powerdns.sh \
  --db mysql \
  --with-recursor \
  --external-ip 192.168.25.60 \
  --lan-cidr "192.168.24.0/22,10.66.66.0/24" \
  --zone doovate.com \
  --upstreams "8.8.8.8;1.1.1.1" \
  --non-interactive

¿Qué hace este comando?
- Instala MariaDB y configura la base de datos para PowerDNS.
- Instala PowerDNS Autoritativo y el backend MySQL.
- Instala el Recursor y lo configura para:
  - Aceptar consultas desde 127.0.0.1, 192.168.24.0/22 y 10.66.66.0/24.
  - Redirigir la zona doovate.com al servidor autoritativo local (puerto 5300).
  - Reenviar el resto de consultas a 8.8.8.8 y 1.1.1.1.
- Mueve el Autoritativo al puerto 5300 para evitar conflicto con el Recursor (53).
- Activa la API del Autoritativo en http://localhost:8081 y guarda las credenciales en /opt/pdns_install/db_credentials.

Verificación rápida
- Estados de servicios:
  systemctl status pdns
  systemctl status pdns-recursor

- Puertos en escucha:
  ss -lntup | grep -E ':(53|5300)'
  # Debes ver recursor en :53 (udp/tcp) y autoritativo en :5300

- Pruebas de resolución:
  dig @192.168.25.60 google.com +short
  # Debe devolver IPs (vía upstreams)

  dig @192.168.25.60 doovate.com SOA +short
  # Si aún no creaste la zona, probablemente NXDOMAIN

Crear la zona autoritativa (ejemplo)
- Crea la zona y algunos registros:
  sudo pdnsutil create-zone doovate.com ns1.doovate.com
  sudo pdnsutil add-record doovate.com @ A 192.168.25.60
  sudo pdnsutil add-record doovate.com www A 192.168.25.60
  sudo systemctl reload pdns

- Prueba de nuevo:
  dig @192.168.25.60 doovate.com A +short
  dig @192.168.25.60 www.doovate.com A +short

Archivos importantes
- Credenciales: /opt/pdns_install/db_credentials
- Autoritativo: /etc/powerdns/pdns.conf y /etc/powerdns/pdns.d/gmysql.conf
- Recursor: /etc/powerdns/recursor.conf

Notas
- Si el sistema usa systemd-resolved, el script puede deshabilitarlo (si aceptas). Asegúrate de tener un nameserver válido en /etc/resolv.conf (por ejemplo 127.0.0.1 si usarás el recursor local).
- Abre en el firewall los puertos necesarios (53/tcp y 53/udp para Recursor; 5300 si accedes al Autoritativo desde fuera).

Soporte
Si algo falla, comparte la salida de:
- journalctl -u pdns -b
- journalctl -u pdns-recursor -b
- cat /etc/powerdns/recursor.conf
- cat /etc/powerdns/pdns.d/gmysql.conf
