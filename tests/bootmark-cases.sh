#!/usr/bin/env bash
# Simulacro j (fase 14): ocarina-bootmark against made-up boots and kernels. Nothing of the real system is read or
# written: OCARINA_BOOTMARK_STATE and OCARINA_BOOTMARK_FAKE point to a temporary directory.
# usage: tests/bootmark-cases.sh        (exit 0 when every case gives the expected verdict)
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export OCARINA_BOOTMARK_STATE="$tmp/state" OCARINA_BOOTMARK_FAKE="$tmp/fake.json"
T=1792200000            # a fixed «now» in the past: install dates and marks around it
pass=0 fail=0

# case <title> <expected kind|ok> <marks json> <fake json>
case_() {
  local title=$1 want=$2 got
  rm -rf "$tmp/state"; mkdir -p "$tmp/state"
  printf '%s\n' "$3" > "$tmp/state/marks.json"
  printf '%s\n' "$4" > "$tmp/fake.json"
  got="$(python3 "$repo/bin/ocarina-bootmark" check | jq -r 'if .ok then "ok" else .alert.kind end')" || true
  if [[ "$got" == "$want" ]]; then pass=$((pass + 1)); printf '  ✓ %-62s → %s\n' "$title" "$got"
  else fail=$((fail + 1)); printf '  ✗ %-62s → %s (esperado %s)\n' "$title" "$got" "$want"; fi
}
mark() { printf '{"bootId":"%s","kernel":"%s","btime":0,"at":%d,"kernels":{}}' "$1" "$2" "$3"; }
k() { printf '{"name":"%s","version":"%s","installed":%d}' "$1" "$2" "$3"; }
b() { printf '{"boot_id":"%s","first_entry":%d}' "$1" "$(( $2 * 1000000 ))"; }

main="7.2.10-1-cachyos" lts="6.18.55-2-cachyos-lts"
M1="[$(mark a "$main" $T)]"
case_ "arranque normal con el kernel de siempre" ok "$M1" \
  "{\"bootId\":\"b\",\"kernel\":\"$main\",\"kernels\":[$(k linux-cachyos 7.2.10-1 $((T - 9000))),$(k linux-cachyos-lts 6.18.55-2 $((T - 9000)))],\"boots\":[$(b a $((T - 100))),$(b b $((T + 600)))]}"
case_ "arranque por LTS tras instalar un kernel nuevo" lts-after-new-kernel "$M1" \
  "{\"bootId\":\"b\",\"kernel\":\"$lts\",\"kernels\":[$(k linux-cachyos 7.2.11-1 $((T + 300))),$(k linux-cachyos-lts 6.18.55-2 $((T - 9000)))],\"boots\":[$(b a $((T - 100))),$(b b $((T + 600)))]}"
case_ "falta la marca del arranque anterior tras un kernel nuevo" missing-mark "$M1" \
  "{\"bootId\":\"c\",\"kernel\":\"$main\",\"kernels\":[$(k linux-cachyos 7.2.11-1 $((T + 300))),$(k linux-cachyos-lts 6.18.55-2 $((T - 9000)))],\"boots\":[$(b a $((T - 100))),$(b b $((T + 600))),$(b c $((T + 1200)))]}"
case_ "falta la marca pero sin kernel nuevo (apagó en el greeter)" ok "$M1" \
  "{\"bootId\":\"c\",\"kernel\":\"$main\",\"kernels\":[$(k linux-cachyos 7.2.10-1 $((T - 9000))),$(k linux-cachyos-lts 6.18.55-2 $((T - 9000)))],\"boots\":[$(b a $((T - 100))),$(b b $((T + 600))),$(b c $((T + 1200)))]}"
case_ "LTS elegido a propósito (ningún kernel nuevo)" ok "$M1" \
  "{\"bootId\":\"b\",\"kernel\":\"$lts\",\"kernels\":[$(k linux-cachyos 7.2.10-1 $((T - 9000))),$(k linux-cachyos-lts 6.18.55-2 $((T - 9000)))],\"boots\":[$(b a $((T - 100))),$(b b $((T + 600)))]}"
case_ "kernel nuevo que ya arrancó bien y luego LTS a propósito" ok \
  "[$(mark a "$main" $T),$(mark b "7.2.11-1-cachyos" $((T + 700)))]" \
  "{\"bootId\":\"c\",\"kernel\":\"$lts\",\"kernels\":[$(k linux-cachyos 7.2.11-1 $((T + 300))),$(k linux-cachyos-lts 6.18.55-2 $((T - 9000)))],\"boots\":[$(b a $((T - 100))),$(b b $((T + 600))),$(b c $((T + 1200)))]}"
case_ "primera marca de todas" ok "[]" \
  "{\"bootId\":\"a\",\"kernel\":\"$main\",\"kernels\":[],\"boots\":[]}"

# the mark itself: an alert writes alert.json (notify-send may fail here: no session is required)
rm -rf "$tmp/state"; mkdir -p "$tmp/state"; printf '%s\n' "$M1" > "$tmp/state/marks.json"
printf '%s\n' "{\"bootId\":\"b\",\"kernel\":\"$lts\",\"kernels\":[$(k linux-cachyos 7.2.11-1 $((T + 300)))],\"boots\":[]}" > "$tmp/fake.json"
PATH="/usr/bin:/bin" OCARINA_NO_NOTIFY=1 python3 "$repo/bin/ocarina-bootmark" mark >/dev/null
if [[ "$(jq -r .kind "$tmp/state/alert.json" 2>/dev/null)" == lts-after-new-kernel && "$(jq length "$tmp/state/marks.json")" == 2 ]]; then
  pass=$((pass + 1)); echo "  ✓ mark: escribe alert.json para Mamori y añade la marca"
else
  fail=$((fail + 1)); echo "  ✗ mark: no escribió alert.json o la marca"
fi
echo "casos: $pass bien · $fail mal"
((fail == 0))
