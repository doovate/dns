#!/usr/bin/env bash
set -euo pipefail

strong_hex() { openssl rand -hex 24; }
strong_pwd() { openssl rand -base64 24 | tr -d '\n' | tr '/+' 'Aa'; }

: "${OUTPUT_FILE:=/dev/stdout}"

DB_PASSWORD=${DB_PASSWORD:-}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-}

if [[ -z "${DB_PASSWORD}" ]]; then DB_PASSWORD=$(strong_pwd); fi
if [[ -z "${ADMIN_PASSWORD}" ]]; then ADMIN_PASSWORD=$(strong_pwd); fi

PDNS_API_KEY=${PDNS_API_KEY:-$(strong_hex)}
PDNS_ADMIN_SECRET_KEY=${PDNS_ADMIN_SECRET_KEY:-$(strong_hex)}
PDNS_ADMIN_API_KEY=${PDNS_ADMIN_API_KEY:-$(strong_hex)}

cat >"$OUTPUT_FILE" <<ENV
DB_PASSWORD=$DB_PASSWORD
ADMIN_PASSWORD=$ADMIN_PASSWORD
PDNS_API_KEY=$PDNS_API_KEY
PDNS_ADMIN_SECRET_KEY=$PDNS_ADMIN_SECRET_KEY
PDNS_ADMIN_API_KEY=$PDNS_ADMIN_API_KEY
ENV
