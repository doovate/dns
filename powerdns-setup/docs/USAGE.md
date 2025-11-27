# Uso de powerdns-setup

1) Edita `config.env` y ajusta los parámetros (IP, zona, puertos, etc.).
2) Ejecuta el instalador en modo interactivo:
   sudo bash install.sh

Modos:
- --auto    Ejecuta sin pausas
- --reset   Reinicia el progreso desde cero
- --resume  Continúa donde se quedó
- --dry-run Simula sin aplicar cambios

El estado se guarda en `.install_progress`. Los logs se escriben en `/var/log/powerdns-setup.log`.

Al finalizar, revisa `CREDENTIALS.txt` (permisos 600) para acceder a la Web UI y a la base de datos.
