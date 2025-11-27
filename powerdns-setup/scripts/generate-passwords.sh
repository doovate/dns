#!/bin/bash
set -euo pipefail
# Generates strong random passwords for provided keys unless already set in env
# Usage: source config.env; ./scripts/generate-passwords.sh

mkpwd() {
  head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9!@#%^&*()_+=' | head -c 24
}

if [ -z "${ADMIN_PASSWORD:-}" ]; then
  echo "ADMIN_PASSWORD=$(mkpwd)"
fi
if [ -z "${DB_PASSWORD:-}" ]; then
  echo "DB_PASSWORD=$(mkpwd)"
fi
if [ -z "${PDNS_API_KEY:-}" ]; then
  head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9A-Z' | head -c 32 | xargs -I{} echo "PDNS_API_KEY={}" 
fi
