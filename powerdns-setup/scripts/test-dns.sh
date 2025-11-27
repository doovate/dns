#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
source "$ROOT_DIR/config.env"

apt update && apt install -y dnsutils >/dev/null 2>&1 || true

echo "Prueba interna (dv-vpn.${DNS_ZONE})"
dig @"${DNS_SERVER_IP}" "dv-vpn.${DNS_ZONE}" +short

echo "Prueba externa (google.com)"
dig @"${DNS_SERVER_IP}" google.com +short
