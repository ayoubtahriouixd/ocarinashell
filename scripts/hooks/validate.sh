#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write) — validates the file Claude just wrote.
# Exit 2 = problem found; stderr goes back to Claude so it fixes it immediately. Missing tools are skipped.
set -uo pipefail

input=$(cat)
file=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null) \
  || file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || file=""
if [[ -z "$file" ]]; then
  re='"file_path"[[:space:]]*:[[:space:]]*"([^"]*)"'
  [[ $input =~ $re ]] && file="${BASH_REMATCH[1]}"
fi
[[ -n "$file" && -f "$file" ]] || exit 0

proj="${OCARINA_REPO:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"   # OCARINA_REPO: set by the Mamori workspace (repo via --add-dir)
# templates/** hold {{token}} placeholders: they are validated through their rendered output
# (`ocarina-theme apply --dry-run`), never as raw KDL/JSON/fish.
[[ $file == "$proj"/templates/* || $file == */ocarinashell/templates/* ]] && exit 0
have() { command -v "$1" >/dev/null 2>&1; }
fail() { printf 'validate.sh → %s\n' "$@" >&2; exit 2; }
first_line=$(head -n1 "$file" 2>/dev/null || true)
pyparse() { python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read(), sys.argv[1])' "$1" 2>&1; }

case "$file" in
  *.kdl)
    if have niri; then
      target="$file"
      # files of the modular config are validated through the root config that includes them
      if [[ "$file" == "$proj"/config/niri/* && -f "$proj/config/niri/config.kdl" ]]; then target="$proj/config/niri/config.kdl"; fi
      out=$(niri validate -c "$target" 2>&1) || fail "niri validate falló ($target) tras editar $file:" "$out"
    fi ;;
  *.qml)
    if have journalctl && systemctl --user is-active --quiet ocarinashell 2>/dev/null; then
      sleep 0.9   # Quickshell hot-reloads on save
      errs=$(journalctl --user -u ocarinashell --since "-5s" -o cat --no-pager 2>/dev/null \
        | grep -Ei 'error|ReferenceError|TypeError|is not a type|cannot assign|failed to (load|reload)|Binding loop|unavailable|not installed' \
        | tail -n 15)
      [[ -z "$errs" ]] || fail "la shell registró problemas al recargar $file (journalctl --user -u ocarinashell):" "$errs"
    fi ;;
  *.json)
    out=$(python3 -m json.tool "$file" 2>&1 >/dev/null) || fail "JSON inválido en $file:" "$out" ;;
  *.toml)
    out=$(python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$file" 2>&1) || fail "TOML inválido en $file:" "$out" ;;
  *.py)
    out=$(pyparse "$file") || fail "Python no compila ($file):" "$out" ;;
  *.lua)
    if have luac; then out=$(luac -p "$file" 2>&1) || fail "Lua con errores ($file):" "$out"
    elif have nvim; then out=$(nvim --headless -u NONE -c "lua local ok,e=loadfile([[$file]]) if not ok then io.stderr:write(tostring(e)) vim.cmd('cq') end" -c q 2>&1) || fail "Lua con errores ($file):" "$out"; fi ;;
  *.fish)
    if have fish; then out=$(fish --no-execute "$file" 2>&1) || fail "fish con errores ($file):" "$out"; fi ;;
  *.sh|*/bin/*|*/scripts/*)
    if [[ "$first_line" =~ ^#!.*(bash|/sh) ]]; then
      out=$(bash -n "$file" 2>&1) || fail "bash -n ($file):" "$out"
      if have shellcheck; then out=$(shellcheck -S warning "$file" 2>&1) || fail "shellcheck ($file):" "$out"; fi
    elif [[ "$first_line" =~ ^#!.*python ]]; then
      out=$(pyparse "$file") || fail "Python no compila ($file):" "$out"
    fi ;;
  */ghostty/config|*/ghostty/*.conf|*/ghostty/config-*)
    if have ghostty; then out=$(ghostty +validate-config --config-file="$file" 2>&1) || fail "Ghostty rechaza $file:" "$out"; fi ;;
esac
exit 0
