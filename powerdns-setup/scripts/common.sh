#!/usr/bin/env bash
set -euo pipefail

# Colors
NC="\e[0m"; BLUE="\e[34m"; GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERROR]${NC} $*"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

# Load config
load_env(){
  if [[ -z "${ENV_LOADED:-}" ]]; then
    test -f "$ROOT_DIR/config.env" || { error "config.env no encontrado"; exit 1; }
    set -a; source "$ROOT_DIR/config.env"; set +a
    ENV_LOADED=1
  fi
}

require_root(){ if [[ $(id -u) -ne 0 ]]; then error "Ejecutar como root"; exit 1; fi }

apt_install(){
  local pkgs=("$@")
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

render_template(){
  # Usage: render_template input.template output
  local in="$1" out="$2"
  sed -e "s/{{DNS_SERVER_IP}}/${DNS_SERVER_IP//\//\\/}/g" \
      -e "s/{{RECURSOR_PORT}}/${RECURSOR_PORT}/g" \
      -e "s/{{AUTHORITATIVE_PORT}}/${AUTHORITATIVE_PORT}/g" \
      -e "s/{{INTERNAL_NETWORK_CIDR}}/${INTERNAL_NETWORK_CIDR//\//\\/}/g" \
      -e "s/{{VPN_NETWORK_CIDR}}/${VPN_NETWORK_CIDR//\//\\/}/g" \
      -e "s/{{FORWARDERS}}/${FORWARDERS//\//\\/}/g" \
      -e "s/{{DNS_ZONE}}/${DNS_ZONE}/g" \
      -e "s/{{PG_PORT}}/${PG_PORT}/g" \
      -e "s/{{PDNS_DB_NAME}}/${PDNS_DB_NAME}/g" \
      -e "s/{{PDNS_DB_USER}}/${PDNS_DB_USER}/g" \
      -e "s/{{PDNS_DB_PASS}}/${PDNS_DB_PASS}/g" \
      -e "s/{{PDNS_API_KEY}}/${PDNS_API_KEY}/g" \
      -e "s/{{PDNS_API_PORT}}/${PDNS_API_PORT}/g" \
      -e "s/{{PDNSA_HTTP_PORT}}/${PDNSA_HTTP_PORT}/g" \
      -e "s/{{PDNSA_FQDN}}/${PDNSA_FQDN}/g" \
      "$in" > "$out"
}

confirm(){
  local msg=${1:-"¿Continuar?"}
  if [[ "${AUTO_APPROVE}" == "true" ]]; then return 0; fi
  read -rp "$msg [y/N]: " ans || true
  [[ "$ans" =~ ^[Yy]$ ]]
}
