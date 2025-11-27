#!/usr/bin/env bash
# Configure PowerDNS Authoritative + Recursor using templates
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_DIR="$BASE_DIR/configs"
# shellcheck disable=SC1090
source "$BASE_DIR/config.env"

log() { echo -e "\e[1;32m[PDNS]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

ensure_pkg() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y pdns-server pdns-backend-pgsql pdns-recursor
}

render() {
  # args: template output
  local t="$1" o="$2"
  sed -e "s/{{PDNS_RECURSOR_PORT}}/${PDNS_RECURSOR_PORT}/g" \
      -e "s/{{DNS_FORWARDER_1}}/${DNS_FORWARDER_1}/g" \
      -e "s/{{DNS_FORWARDER_2}}/${DNS_FORWARDER_2}/g" \
      -e "s/{{DNS_ZONE}}/${DNS_ZONE}/g" \
      -e "s/{{PDNS_AUTH_PORT}}/${PDNS_AUTH_PORT}/g" \
      -e "s/{{DB_NAME}}/${DB_NAME}/g" \
      -e "s/{{DB_USER}}/${DB_USER}/g" \
      -e "s/{{DB_PASSWORD}}/${DB_PASSWORD}/g" \
      -e "s/{{PDNS_API_KEY}}/${PDNS_API_KEY}/g" "$t" >"$o"
}

main() {
  ensure_pkg
  mkdir -p /etc/powerdns /etc/pdns /etc/powerdns/recursor

  # Render pdns authoritative config
  local pdns_tpl="$CONF_DIR/pdns.conf.template"
  local pdns_out="/etc/powerdns/pdns.conf"
  render "$pdns_tpl" "$pdns_out"
  chmod 640 "$pdns_out" || true

  # If MySQL chosen, adjust launch
awk -v dbt="$DB_TYPE" 'BEGIN{OFS="="} /^launch=/{ if (dbt=="mysql") $0="launch=gmysql"; print; next } { print }' "$pdns_out" >"$pdns_out.tmp" && mv "$pdns_out.tmp" "$pdns_out"

  # Render recursor
  local rec_tpl="$CONF_DIR/recursor.conf.template"
  local rec_out="/etc/powerdns/recursor.conf"
  render "$rec_tpl" "$rec_out"
  chmod 640 "$rec_out" || true

  systemctl enable --now pdns || true
  systemctl enable --now pdns-recursor || true
  systemctl restart pdns pdns-recursor

  log "PowerDNS configured and restarted."
}

main "$@"
