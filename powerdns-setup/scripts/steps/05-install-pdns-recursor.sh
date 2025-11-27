#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

render_template(){
  local tpl="$1"; shift
  local out="$1"; shift
  local content
  content=$(cat "$tpl")
  content=${content//\{\{PDNS_AUTH_PORT\}\}/$PDNS_AUTH_PORT}
  content=${content//\{\{DNS_SERVER_IP\}\}/$DNS_SERVER_IP}
  content=${content//\{\{INTERNAL_NETWORK\}\}/$INTERNAL_NETWORK}
  content=${content//\{\{VPN_NETWORK\}\}/$VPN_NETWORK}
  content=${content//\{\{DNS_ZONE\}\}/$DNS_ZONE}
  content=${content//\{\{DNS_FORWARDER_1\}\}/$DNS_FORWARDER_1}
  content=${content//\{\{DNS_FORWARDER_2\}\}/$DNS_FORWARDER_2}
  echo "$content" > "$out"
}

main(){
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y pdns-recursor"

  render_template "$ROOT_DIR/configs/recursor.conf.template" /etc/powerdns/recursor.conf

  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl restart pdns-recursor"
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "systemctl enable pdns-recursor"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
