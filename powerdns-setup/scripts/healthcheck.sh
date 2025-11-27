#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
source "$ROOT_DIR/config.env"

ok(){ echo -e "\033[0;32m[OK]\033[0m $1"; }
warn(){ echo -e "\033[0;33m[WARN]\033[0m $1"; }
fail(){ echo -e "\033[0;31m[FAIL]\033[0m $1"; }

check_service(){
  local svc="$1"; local name="$2"
  if systemctl is-active --quiet "$svc"; then ok "$name"; else fail "$name"; fi
}

check_port(){
  local ip="$1"; local port="$2"; local name="$3"
  if timeout 2 bash -c "</dev/tcp/${ip}/${port}" 2>/dev/null; then ok "$name (${ip}:${port})"; else fail "$name (${ip}:${port})"; fi
}

main(){
  check_service pdns "PowerDNS Authoritative"
  check_service pdns-recursor "PowerDNS Recursor"
  check_service powerdns-admin "PowerDNS-Admin"
  check_service nginx "Nginx"

  check_port "$DNS_SERVER_IP" "$PDNS_RECURSOR_PORT" "Recursor"
  check_port "127.0.0.1" "$PDNS_AUTH_PORT" "Authoritative"
  check_port "$DNS_SERVER_IP" "$NGINX_HTTPS_PORT" "Nginx HTTPS"
}

main "$@"
