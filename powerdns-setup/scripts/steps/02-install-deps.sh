#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR/.."
source scripts/lib/colors.sh
source scripts/lib/logging.sh
source scripts/lib/progress.sh
source scripts/lib/errors.sh
source config.env

log_info "PASO 2: Instalación de dependencias"

# Idempotent checks
if command -v apt >/dev/null 2>&1; then
  PKG_MGR=apt
else
  log_warn "Gestor de paquetes no soportado. Este script asume Ubuntu (apt)."
  PKG_MGR=apt
fi

run_cmd apt-get update -y
run_cmd apt-get install -y curl ca-certificates gnupg lsb-release jq git python3 python3-venv python3-pip ufw nginx openssl bind9-dnsutils gettext-base

log_success "Dependencias instaladas"
