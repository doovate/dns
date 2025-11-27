# Arquitectura de despliegue PowerDNS

Componentes:
- PowerDNS Authoritative (pdns-server): publica zonas internas desde MariaDB en puerto 5300 (bind local a 192.168.25.60)
- PowerDNS Recursor (pdns-recursor): recibe todas las consultas en 53/udp,tcp y reenvía
  - Zonas internas (doovate.com) a Authoritative local 127.0.0.1:5300
  - Resto (.) a forwarders 8.8.8.8 y 1.1.1.1
- MariaDB: almacena esquema PowerDNS (domains, records, etc.)
- PowerDNS-Admin: interfaz web; gunicorn escucha en 127.0.0.1:8000
- Nginx: reverse proxy HTTPS 443 -> gunicorn
- UFW: restringe acceso a 53 (UDP desde redes internas/VPN) y 443 (TCP desde redes internas/VPN)

Flujo de consultas DNS:
Cliente -> Recursor:53 -> (si dominio interno) -> Auth:5300 -> Respuesta
                                   \-> (dominio externo) -> Forwarders -> Respuesta

Puertos:
- 53/udp,tcp Recursor en 192.168.25.60
- 5300/tcp    Authoritative en 192.168.25.60 y 127.0.0.1
- 8000/tcp    Gunicorn local
- 443/tcp     Nginx HTTPS expuesto

Seguridad:
- Servicios gestionados por systemd
- Certificado self-signed por defecto
- Contraseñas generadas automáticamente (openssl)
- UFW activo por defecto (opcional)

Reanudabilidad:
- Archivo `.install_progress` guarda el estado por paso
- `install.sh --resume` continúa donde se quedó

Compatibilidad Python 3.12:
- Uso de `python3-venv` y `pip` dentro del venv; no se usa `distutils` ni `virtualenv`.
