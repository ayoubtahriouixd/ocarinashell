#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) — blocks catastrophic, boot-touching or session-killing commands.
# Exit 2 = blocked; stderr goes back to Claude. Hooks run in every permission mode, including bypass.
# The real parser is guard.py (stdlib Python, shell-aware; tests: test-guard.py). If Python itself is broken (e.g. in
# the middle of an upgrade) a coarse keyword fallback blocks anything that even looks dangerous: fail closed.
set -uo pipefail

input=$(cat)
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if command -v python3 >/dev/null 2>&1 && python3 -c 'import json, shlex, re' >/dev/null 2>&1; then
  printf '%s' "$input" | python3 "$here/guard.py"
  exit $?
fi

# ---- emergency fallback (no working python3): coarse, errs on the side of blocking
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || cmd=""
if [[ -z "$cmd" ]]; then
  re='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  if [[ $input =~ $re ]]; then cmd="${BASH_REMATCH[1]}"; else cmd="$input"; fi
fi
danger='(^|[^a-z-])(reboot|poweroff|halt|shutdown|kexec|mkfs|wipefs|sgdisk|parted|fdisk|gdisk|blkdiscard|cryptsetup|mkinitcpio|dracut|limine|efibootmgr|bootctl|fwupdmgr|visudo|sudoers|pam\.d|/boot|/efi|sysrq|subvolume[[:space:]]+delete|scripts/root/)([^a-z-]|$)'
if [[ $cmd =~ $danger ]] || [[ $cmd =~ snapper.*(delete|rollback|undochange) ]] || [[ $cmd =~ niri[[:space:]]+msg.*quit ]] \
   || [[ $cmd =~ systemctl.*(reboot|poweroff|suspend|hibernate|isolate|exit|stop|restart|kill|mask) ]] \
   || [[ $cmd =~ rm[[:space:]]+-[a-zA-Z]*[rR] ]] || [[ $cmd =~ (curl|wget).*\|.*(sh|bash) ]] || [[ $cmd =~ dd[[:space:]].*of=/dev/ ]]; then
  printf 'BLOQUEADO por scripts/hooks/guard.sh (modo de emergencia: python3 no funciona, así que la guardia es estricta).\nArregla Python primero o pide a Ayoub que lo ejecute él.\n' >&2
  exit 2
fi
exit 0
