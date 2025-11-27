# PowerDNS Setup

Instalador modular y controlado para desplegar un stack de PowerDNS en Ubuntu 24.04:
- PowerDNS Authoritative (puerto configurable)
- PowerDNS Recursor (puerto 53 por defecto)
- PowerDNS-Admin (con venv y systemd)
- Nginx como reverse proxy con SSL autofirmado
- UFW para firewall restrictivo

Características clave:
- 12 pasos orquestados con reanudación y detección de estado
- Modo interactivo y modo dry-run
- Logging detallado con ofuscación de secretos
- Manejo de errores con reintentar/saltar/abortar
- Resumen final con accesos y tiempos

## Requisitos
- Ubuntu 24.04 (recomendado)
- Acceso root o sudo
- Conectividad a Internet

## Estructura
Ver sección "Estructura del proyecto" más abajo.

## Uso rápido
1) Edita config.env con tus parámetros.
2) Ejecuta instalación:

    sudo bash install.sh --verbose

Para simular sin cambios reales:

    sudo bash install.sh --dry-run

Para no pedir confirmaciones:

    sudo bash install.sh --non-interactive

Para reintentar una instalación previa automáticamente, solo vuelve a ejecutar `install.sh`. Para empezar desde cero:

    sudo bash install.sh --no-resume

## Seguridad
- Contraseñas generadas con alta entropía si no se proporcionan
- Certificado SSL autofirmado para la web
- UFW permitiendo solo DNS desde redes internas y WebUI desde redes internas
- CREDENTIALS.txt con permisos 600
- Logs con secretos ofuscados

## Pasos
1. Verificación del sistema
2. Instalación de dependencias
3. Configuración de base de datos
4. Instalación PowerDNS Authoritative
5. Instalación PowerDNS Recursor
6. Configuración de zonas DNS
7. Instalación PowerDNS-Admin
8. Configuración de nginx
9. Configuración de firewall
10. Generación de credenciales
11. Inicio de servicios
12. Pruebas finales

## Desinstalar

    sudo bash uninstall.sh --purge-data

## Documentación adicional
- INSTALL.md: guía detallada
- docs/USAGE.md: uso de la interfaz web
- docs/TROUBLESHOOTING.md: problemas comunes
- docs/ARCHITECTURE.md: arquitectura del despliegue
