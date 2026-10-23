#!/usr/bin/env bash
# OcarinaShell · 守 Mamori's only passwordless root command: /etc/sudoers.d/91-ocarina-maint lets <user> run
# /usr/local/libexec/ocarina-maint (which validates every argument against its own whitelist, docs/06 › Seguridad del
# piloto automático) and nothing else. Checked with `visudo -c` before it is installed and again after; idempotent.
# usage: sudo bash scripts/root/mamori-sudo.sh <usuario>      · remove: sudo bash scripts/root/mamori-sudo.sh --quitar
set -euo pipefail
export LC_ALL=C
helper=/usr/local/libexec/ocarina-maint
rule=/etc/sudoers.d/91-ocarina-maint
die() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
((EUID == 0)) || die "ejecútalo con sudo"
if [[ "${1:-}" == --quitar ]]; then rm -f "$rule"; echo "  quitada $rule"; exit 0; fi
user="${1:-${SUDO_USER:-}}"
if ! [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || ! id "$user" >/dev/null 2>&1; then die "usuario no válido: ${user:-(ninguno)}"; fi
[[ -x "$helper" ]] || die "falta $helper (sudo bash scripts/install-system.sh)"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<RULE
# OcarinaShell · 守 Mamori: the ONLY passwordless root command. ocarina-maint validates every argument against its own
# whitelist. Installed by scripts/root/mamori-sudo.sh after visudo -c; remove with: sudo rm $rule
Defaults!$helper env_reset, !requiretty
$user ALL=(root) NOPASSWD: $helper
RULE
visudo -cqf "$tmp" || die "visudo -c rechaza la regla: no se instala"
if cmp -s "$tmp" "$rule" 2>/dev/null; then echo "  ya estaba $rule"
else install -o root -g root -m 0440 "$tmp" "$rule"; echo "  instalada $rule"; fi
visudo -cq || { rm -f "$rule"; die "visudo -c falla con la regla puesta: la quito"; }
