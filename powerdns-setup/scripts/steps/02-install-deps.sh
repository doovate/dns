#!/usr/bin/env bash
set -euo pipefail

STEP_KEY="$1"; STEP_TITLE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

source "$ROOT_DIR/config.env"
source "$ROOT_DIR/scripts/lib/logging.sh"
source "$ROOT_DIR/scripts/lib/progress.sh"
source "$ROOT_DIR/scripts/lib/errors.sh"

main(){
  # paquetes base
  local pkgs=(curl wget git gnupg ca-certificates software-properties-common)

  # apt update
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt update"
  # instalar
  run_or_recover "$STEP_TITLE" "$STEP_KEY" "apt install -y ${pkgs[*]}"

  progress_set "$STEP_KEY" "completed"
}

main "$@"
