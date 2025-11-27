#!/usr/bin/env bash
set -euo pipefail
# Simple DNS tests after installation
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$BASE_DIR/config.env"

log() { echo -e "\e[1;34m[TEST]\e[0m $*"; }

if ! command -v dig >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y dnsutils >/dev/null
fi

log "Testing resolution for ${DNS_ZONE} root (@) SOA via recursor"
dig +short @127.0.0.1 -p ${PDNS_RECURSOR_PORT} ${DNS_ZONE} SOA || true

for rec in "$DNS_RECORD_1" "$DNS_RECORD_2" "$DNS_RECORD_3"; do
  host=$(echo "$rec" | cut -d: -f1)
  fqdn="${host}.${DNS_ZONE}"
  log "Testing A record for ${fqdn}"
  dig +short @127.0.0.1 -p ${PDNS_RECURSOR_PORT} ${fqdn} A || true
done

log "Done. If records are blank, check services and logs."
