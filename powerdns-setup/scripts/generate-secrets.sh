#!/usr/bin/env bash
set -euo pipefail

# This script generates strong passwords/secrets into config.env
# It is idempotent: only replaces known defaults or empty values.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CONFIG="$ROOT_DIR/config.env"

if [[ ! -f "$CONFIG" ]]; then
  echo "[ERROR] config.env no encontrado en $ROOT_DIR" >&2
  exit 1
fi

backup_config(){
  local ts
  ts=$(date +%Y%m%d-%H%M%S)
  cp -a "$CONFIG" "$CONFIG.bak.$ts"
}

# Generators
rand_alnum(){
  # length $1
  local len=${1:-24}
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
}
rand_hex(){
  local len=${1:-64}
  # length in hex chars
  hexdump -vn "$((len/2))" -e '"%02X"' /dev/urandom 2>/dev/null || openssl rand -hex "$((len/2))"
}

# Get current value without quotes
get_var(){
  local key="$1"
  local line val
  line=$(grep -E "^${key}=" "$CONFIG" || true)
  [[ -z "$line" ]] && { echo ""; return 0; }
  val=${line#*=}
  # strip surrounding quotes (handles both " and ')
  val="${val%\"}"
  val="${val#\"}"
  val="${val%\'}"
  val="${val#\'}"
  echo "$val"
}

# Replace line KEY=... with KEY=value, optionally quoted
set_var(){
  local key="$1" value="$2" quote=${3:-no}
  local replacement
  if [[ "$quote" == "yes" ]]; then
    replacement="${key}=\"${value}\""
  else
    replacement="${key}=${value}"
  fi
  # If key exists, replace; else append
  if grep -qE "^${key}=" "$CONFIG"; then
    sed -i "s|^${key}=.*|${replacement}|" "$CONFIG"
  else
    echo "$replacement" >> "$CONFIG"
  fi
}

changed=0
summary=()

# Ensure backup once if any change occurs
ensure_backup(){ if (( changed==0 )); then backup_config; fi; changed=1; }

# PDNS DB password
current=$(get_var PDNS_DB_PASS)
if [[ -z "$current" || "$current" == "pdns_pass" ]]; then
  ensure_backup
  new=$(rand_alnum 28)
  set_var PDNS_DB_PASS "$new" no
  summary+=("PDNS_DB_PASS: ${new}")
fi

# PDNS Admin (PowerDNS-Admin app DB user) password
current=$(get_var PDNSADMIN_DB_PASS)
if [[ -z "$current" || "$current" == "pdnsadmin_pass" ]]; then
  ensure_backup
  new=$(rand_alnum 28)
  set_var PDNSADMIN_DB_PASS "$new" no
  summary+=("PDNSADMIN_DB_PASS: ${new}")
fi

# PowerDNS API key
current=$(get_var PDNS_API_KEY)
if [[ -z "$current" || "$current" == "change_me_secure_api_key" ]]; then
  ensure_backup
  new=$(rand_hex 64)
  set_var PDNS_API_KEY "$new" yes
  summary+=("PDNS_API_KEY: ${new}")
fi

# PowerDNS-Admin initial admin password
current=$(get_var PDNSA_ADMIN_PASSWORD)
if [[ -z "$current" || "$current" == "ChangeMe_StrongPwd1!" ]]; then
  ensure_backup
  new=$(rand_alnum 16)
  set_var PDNSA_ADMIN_PASSWORD "$new" yes
  summary+=("PDNSA_ADMIN_PASSWORD: ${new}")
fi

# Optional: generate MYSQL_ROOT_PASS if empty and MySQL chosen (future-proof)
if grep -qE '^DB_ENGINE=MYSQL' "$CONFIG"; then
  current=$(get_var MYSQL_ROOT_PASS)
  if [[ -z "$current" ]]; then
    ensure_backup
    new=$(rand_alnum 24)
    set_var MYSQL_ROOT_PASS "$new" yes
    summary+=("MYSQL_ROOT_PASS: ${new}")
  fi
fi

if (( changed==1 )); then
  echo "[INFO] Se generaron/actualizaron secretos en config.env:"
  for s in "${summary[@]}"; do echo " - $s"; done
else
  echo "[INFO] Secretos ya establecidos; no se realizaron cambios."
fi
