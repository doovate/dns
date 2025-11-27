#!/bin/bash
set -euo pipefail
ZONE=${1:-}
SERVER_IP=${2:-127.0.0.1}
if [ -z "$ZONE" ]; then
  echo "Uso: $0 <zona> [servidor_ip]"
  exit 1
fi

if ! command -v dig >/dev/null 2>&1; then
  echo "dig no está instalado (paquete dnsutils)"
  exit 0
fi

echo "Probando resolución interna para zona $ZONE en $SERVER_IP"
set +e
rc1=$(dig +short @$SERVER_IP $ZONE SOA)
rc2=$(dig +short @$SERVER_IP $ZONE NS)
rc3=$(dig +short @$SERVER_IP dns.$ZONE A)
set -e

echo "SOA: $rc1"
echo "NS: $rc2"
echo "A dns: $rc3"

if [ -n "$rc1" ] && [ -n "$rc2" ]; then
  echo "OK: Zona responde"
else
  echo "FALLO: La zona no responde correctamente"
fi
