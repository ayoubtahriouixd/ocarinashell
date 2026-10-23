#!/usr/bin/env bash
# Fase 06 · real lock cycles WITH AYOUB PRESENT (rule 3). Locks through the shell, waits for the unlock and logs
# timings; Ayoub types the password each time (a wrong one now and then). Never types anything itself.
# usage: tests/kagi_ciclos.sh [N=20] [log]
set -euo pipefail
n="${1:-20}"
log="${2:-docs/evidencias/fase-06/kagi-ciclos.txt}"
st() { timeout 2 qs -c ocarina ipc call lock state 2>/dev/null || echo '{}'; }
field() { python3 -c "import json,sys; d=json.loads(sys.argv[1] or '{}'); print(d.get(sys.argv[2], ''))" "$1" "$2"; }
echo "# Kagi · $n ciclos reales · $(date -Iseconds)" | tee "$log"
for i in $(seq "$n"); do
  t0=$(date +%s%N)
  qs -c ocarina ipc call lock lock >/dev/null
  secure_ms=""
  for _ in $(seq 50); do
    s=$(st)
    if [[ "$(field "$s" locked)" == True ]]; then secure_ms=$(( ($(date +%s%N) - t0) / 1000000 )); break; fi
    sleep 0.05
  done
  [[ -n "$secure_ms" ]] || { echo "ciclo $i: NO se confirmó el bloqueo en 2,5 s · $(st)" | tee -a "$log"; }
  # wait for the unlock (Ayoub), up to 10 min
  fails=0
  for _ in $(seq 2400); do
    s=$(st)
    f=$(field "$s" failures); [[ -n "$f" ]] && fails=$f
    [[ "$(field "$s" active)" == False ]] && break
    sleep 0.25
  done
  dt=$(( ($(date +%s%N) - t0) / 1000000 ))
  echo "ciclo $i: bloqueado en ${secure_ms:-?} ms · desbloqueado tras $((dt / 1000)) s · fallos $fails · fallback $(field "$(st)" fallback)" | tee -a "$log"
  sleep 3
done
echo "# fin · faillock: $(faillock --user "$USER" | tail -n +3 | wc -l) entradas" | tee -a "$log"
