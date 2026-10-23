#!/usr/bin/env bash
# 守 Mamori · simulacro a (fase 16): «una actualización cambia una API y rompe la shell». En una rama de prueba,
# shell/modules/polkit/Polkit.qml pasa a usar un nombre de señal que no existe (como si Quickshell lo hubiera
# renombrado): el agente de polkit no carga y las pruebas de humo activas fallan. Mamori pide a Snake un diagnóstico y
# hasta 3 parches en mamori/compat-<fecha>; si las pruebas pasan, fusiona («Snake adapta»); si no, la reversión de la
# transacción (aquí en seco: no hubo transacción real) + retención («Mamori revierte»). Pase lo que pase, vuelve a
# main y borra las ramas de prueba. Restarts the shell on screen (active smoke tests): run it with Ayoub watching.
#   bash tests/mamori-simulacro-a.sh
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$repo/docs/evidencias/fase-16/simulacro-a.txt"
scratch="$(mktemp -d)"
branch=prueba/simulacro-a
cd "$repo" || exit 2
[[ "$(git rev-parse --abbrev-ref HEAD)" == main ]] || { echo "el repo no está en main" >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "hay cambios sin commit" >&2; exit 2; }

cleanup() {
  git switch -q main 2>/dev/null
  git branch -D "$branch" >/dev/null 2>&1
  for b in $(git branch --list 'mamori/compat-*' --format='%(refname:short)'); do git branch -D "$b" >/dev/null 2>&1; done
  systemctl --user restart ocarinashell
  rm -rf "$scratch"
}
trap cleanup EXIT

git switch -q -c "$branch"
sed -i 's/onIsRegisteredChanged: console.info("Polkit: agente " + (isRegistered/onRegisteredChanged: console.info("Polkit: agente " + (registered/' \
  shell/modules/polkit/Polkit.qml
git commit -qam "simulacro a: PolkitAgent.isRegistered → registered (API cambiada, simulada)"
broken="$(git rev-parse --short HEAD)"
echo '{"adaptBase": "prueba/simulacro-a", "maintDry": true}' > "$scratch/fake.json"
t0="$(date +%s)"
{
  echo "# Simulacro a · actualización que rompe la shell · $(date '+%F %T')"
  echo "rama de prueba $branch @ $broken:"
  git show --stat --format='  %s' HEAD | sed 's/^/  /'
  git show HEAD -- shell/modules/polkit/Polkit.qml | grep '^[-+] ' | sed 's/^/  /'
  echo
  echo "## Pruebas de humo + adaptación (ocarina-mamori adapt)"
} > "$out"
OCARINA_MAMORI_STATE="$scratch" OCARINA_MAMORI_FAKE="$scratch/fake.json" "$repo/bin/ocarina-mamori" adapt > "$scratch/adapt.txt" 2>&1
rc=$?
cat "$scratch/adapt.txt" >> "$out"
for d in "$scratch"/adapt/*.diff; do [[ -f "$d" ]] && { echo "--- parche de Snake: ${d##*/}"; cat "$d"; echo; } >> "$out"; done
{
  echo
  echo "## Journal de Mamori y Snake"
  journalctl -t ocarina-mamori --since "@$t0" -o cat --no-pager
  journalctl -t ocarina-snake --since "@$t0" -o cat --no-pager | grep -E '^tarea ' | cut -c1-600
  echo
  echo "## Ramas tras la adaptación"
  git log --oneline -4 "$branch" | sed 's/^/  /'
  if ((rc == 0)); then
    echo "  parche de Snake:"; git show "$branch" -- shell | grep '^[-+] ' | sed 's/^/    /'
    echo
    echo "VEREDICTO: SUPERADO — Snake adaptó el código; pruebas activas en verde; commit compat: en la rama base"
  else
    echo
    echo "## Sin adaptación → reversión (en seco: el simulacro no hizo una transacción real)"
    OCARINA_MAMORI_STATE="$scratch" OCARINA_MAMORI_FAKE="$scratch/fake.json" python3 -I -c "
import sys; sys.path.insert(0, '$repo/lib')
from mamori import rollback
print(rollback.undo_last('pruebas de humo en rojo tras la actualización simulada', hold_names=['quickshell']))"
    cat "$scratch/holds.json" 2>/dev/null; echo
    echo "VEREDICTO: SUPERADO — sin arreglo válido de Snake ($(grep -m1 'sin adaptación' "$scratch/adapt.txt" | cut -c1-160)); Mamori revierte (último par pre/post, en seco) y retiene el lote"
  fi
} >> "$out" 2>&1
cat "$out"
