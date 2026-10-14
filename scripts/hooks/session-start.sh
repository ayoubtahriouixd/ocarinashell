#!/usr/bin/env bash
# SessionStart hook — puts the live project state in front of Claude (stdout is added to its context).
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

echo "=== OcarinaShell · estado ==="
if [[ -f docs/PROGRESS.md ]]; then
  sed -n '/^| Fase/,/^Leyenda/p' docs/PROGRESS.md | grep -E '^\| [0-9]+ .*(🟨|⛔)' || echo "(ninguna fase en curso o bloqueada)"
  echo "--- últimas entradas del registro ---"
  sed -n '/^## Registro/,$p' docs/PROGRESS.md | tail -n 25
fi
echo "--- git ---"
git log --oneline -5 2>/dev/null || echo "(sin repo git todavía: la fase 0 lo crea)"
git status --short 2>/dev/null | head -n 12
echo "--- entorno ---"
if sudo -n true 2>/dev/null; then echo "sudo: sin contraseña (drop-in temporal activo; se elimina en la fase 17)"
else echo "sudo: pide contraseña → usa scripts/root/*.sh para que Ayoub los ejecute"; fi
command -v niri >/dev/null 2>&1 && niri --version 2>/dev/null | head -n1
command -v qs >/dev/null 2>&1 && qs --version 2>/dev/null | head -n1
systemctl --user is-active ocarinashell >/dev/null 2>&1 && echo "ocarinashell.service: activo" || echo "ocarinashell.service: inactivo"
if [[ -f "$HOME/.local/state/ocarinashell/mamori/status.json" ]]; then
  echo "--- 守 Mamori ---"; head -c 600 "$HOME/.local/state/ocarinashell/mamori/status.json"; echo
fi
echo "Recuerda: snapshot antes de tocar el sistema, verificación visual con capturas, nunca matar la sesión."
exit 0
