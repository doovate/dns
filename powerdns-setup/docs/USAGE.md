# Uso de PowerDNS-Admin

Una vez instalado el stack, accede a la interfaz web:

  https://IP_DEL_SERVIDOR:PUERTO_WEBUI

Reemplaza IP_DEL_SERVIDOR y PUERTO_WEBUI por `DNS_SERVER_IP` y `WEBUI_PORT` de tu config. El certificado es autofirmado; acepta la advertencia del navegador.

## Inicio de sesión
- Usuario: `ADMIN_USERNAME`
- Contraseña: la verás en `CREDENTIALS.txt` o en tu `config.env` si la definiste.

## Configuración inicial recomendada
- Navega a Settings -> PDNS para verificar la URL de API y API Key.
- Añade tus usuarios y roles.
- Importa o crea zonas adicionales.

## Operaciones comunes
- Crear/editar registros en Zonas.
- Delegar subzonas.
- Revisar cambios y auditoría.

## Seguridad
- Cambia la contraseña del admin en el primer inicio.
- Considera reemplazar el certificado SSL por uno emitido por tu CA.
- Limita aún más el acceso a la WebUI mediante VPN o listas de control de acceso adicionales.
