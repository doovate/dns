#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
source "$ROOT_DIR/config.env"

new_pass(){ openssl rand -base64 24 | tr -d "=+/" | cut -c1-20; }

if [ -z "${DB_PASSWORD}" ]; then
  DB_PASSWORD=$(new_pass)
  sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" "$ROOT_DIR/config.env"
  echo "DB_PASSWORD generado y guardado."
else
  echo "DB_PASSWORD ya está establecido."
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  ADMIN_PASSWORD=$(new_pass)
  sed -i "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=${ADMIN_PASSWORD}/" "$ROOT_DIR/config.env"
  echo "ADMIN_PASSWORD generado y guardado."
else
  echo "ADMIN_PASSWORD ya está establecido."
fi
