#!/usr/bin/env bash
set -Eeuo pipefail

# git-pull-safe.sh — Ayuda a ejecutar `git pull` cuando hay cambios locales
# Flujo por defecto:
#   1) git stash push --include-untracked --message "git-pull-safe auto"
#   2) git pull --rebase
#   3) git stash pop (si existe stash creado)
#
# Opciones:
#   --no-pop     No aplicar el stash tras el pull (deja los cambios guardados)
#   --no-rebase  Usar merge en lugar de rebase (git pull --no-rebase)
#   --dry-run    Mostrar lo que haría sin ejecutar
#   -h|--help    Mostrar ayuda
#
# Uso típico en tu repo:
#   cd /ruta/al/repo
#   bash powerdns-setup/scripts/git-pull-safe.sh
#
# Si aparecen conflictos durante `stash pop`, resuélvelos y ejecuta:
#   git add <archivos_resueltos>
#   git commit (si es necesario)
#   # No queda ningún stash pendiente si `stash pop` aplicó correctamente

DRY=false
POP=true
REBASE=true

usage() {
  cat <<USAGE
Uso: bash powerdns-setup/scripts/git-pull-safe.sh [opciones]

Opciones:
  --no-pop     No hacer 'git stash pop' automáticamente después de pull
  --no-rebase  Realizar 'git pull' con merge (por defecto usa --rebase)
  --dry-run    Mostrar comandos sin ejecutarlos
  -h, --help   Esta ayuda
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --no-pop) POP=false ;;
    --no-rebase) REBASE=false ;;
    --dry-run) DRY=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $arg"; usage; exit 1 ;;
  esac
done

run() {
  echo "+ $*"
  if [[ "$DRY" == false ]]; then
    "$@"
  fi
}

# Verificaciones básicas
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git no está instalado en este sistema." >&2
  exit 1
fi

# Asegurar que estamos dentro de un repo git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: este directorio no parece ser un repositorio git." >&2
  exit 1
fi

# Mostrar rama y remote
BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE=$(git remote 2>/dev/null | head -n1 || true)
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || true)
echo "Repositorio: $PWD"
echo "Rama actual: ${BRANCH}"
if [[ -n "$REMOTE" ]]; then
  echo "Remoto: ${REMOTE} (${REMOTE_URL})"
else
  echo "Remoto: (ninguno configurado)"
fi

echo "Estado del árbol de trabajo:"
run git status --short

# Comprobar si hay cambios
if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo "\nCambios locales detectados. Creando stash temporal (incluye no rastreados)."
  run git stash push --include-untracked --message "git-pull-safe auto" || true
  CREATED_STASH=true
else
  CREATED_STASH=false
fi

# Traer últimos cambios
echo "\nActualizando del remoto..."
if [[ "$REBASE" == true ]]; then
  run git pull --rebase
else
  run git pull --no-rebase
fi

# Aplicar stash si fue creado
if [[ "$POP" == true && "$CREATED_STASH" == true ]]; then
  echo "\nAplicando cambios del stash..."
  if ! run git stash pop; then
    echo "\nAviso: Conflictos al aplicar el stash. Procede así:"
    echo "  1) Revisa archivos en conflicto (git status)"
    echo "  2) Edita y resuelve conflictos"
    echo "  3) git add <archivos_resueltos>"
    echo "  4) git commit (si corresponde)"
    echo "\nEl stash puede quedar pendiente si no se aplicó completamente. Lista stashes con:"
    echo "  git stash list"
    exit 2
  fi
else
  if [[ "$CREATED_STASH" == true ]]; then
    echo "\nSe creó un stash pero no se aplicó automáticamente (opción --no-pop)."
    echo "Puedes aplicarlo después con: git stash pop"
  fi
fi

echo "\nHecho. Estado actual:"
run git status --short
