#!/usr/bin/env bash
# shellcheck disable=SC2015  # rec always returns 0, so `test && rec ok … || rec fail …` is a safe if/else
# OcarinaShell · pruebas de humo (docs/06-ACTUALIZACIONES capa 5) = `ocarina doctor --post-update`.
# usage: scripts/smoke-test.sh [--post-update | --active] [--json] [--quiet]
#   (default)      passive checks only: nothing changes on screen (safe to run any time, < 10 s)
#   --active       also the visible ones: restart the shell (must answer by IPC within 5 s with no QML errors) and open
#                  and close the lock in test mode (skipped while the screen is really locked)
#   --post-update  = --active, after a pacman transaction (ocarina-postupdate.service, ocarina update, Mamori)
#   --json         print the report instead of the human summary    --quiet  only failures and the verdict
# Report: ~/.local/state/ocarinashell/smoke.json { at, mode, ok, durationMs, failures, warnings, versions, checks[] }
# with checks[] = { id, level: ok|warn|fail, msg, ms }. Exit 0 when nothing failed, 1 otherwise. Warnings never fail
# (deprecations, Nameraka, optional pieces): they are for Mamori's playbook, not a reason to roll back.
# Extensible: every executable in scripts/smoke.d/ (and ~/.config/ocarinashell/smoke.d/) runs too and prints one JSON
# check per line (same fields). Budget: < 30 s in total; every check has its own timeout.
set -uo pipefail   # no -e: every check runs even if an earlier one fails

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell"
report="$state/smoke.json"
export LC_ALL=C.UTF-8
mode=passive json=0 quiet=0
for a in "$@"; do
  case "$a" in
    --post-update) mode=post-update ;;
    --active) mode=active ;;
    --json) json=1 ;;
    --quiet|-q) quiet=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opción desconocida: $a" >&2; exit 2 ;;
  esac
done
active=0; [[ $mode != passive ]] && active=1

tmp="$(mktemp -d "${TMPDIR:-/tmp}/ocarina-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
t_start=$(date +%s%N)
have() { command -v "$1" >/dev/null 2>&1; }
now_ms() { echo $(( $(date +%s%N) / 1000000 )); }
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
# rec <id> <ok|warn|fail> <message> [ms] — one result line (each check writes its own file: parallel-safe)
rec() { jq -nc --arg i "$1" --arg l "$2" --arg m "$3" --argjson t "${4:-0}" '{id: $i, level: $l, msg: $m, ms: $t}' \
          >> "$tmp/r.$1"; }
# timed <id> <function>: runs the check function and stamps its duration on the lines it wrote
timed() {
  local id=$1 t0; shift; t0=$(now_ms)
  "$@"
  local dt=$(( $(now_ms) - t0 ))
  [[ -f "$tmp/r.$id" ]] && jq -c --argjson t "$dt" '.ms = (if .ms == 0 then $t else .ms end)' "$tmp/r.$id" > "$tmp/r.$id.t" \
    && mv "$tmp/r.$id.t" "$tmp/r.$id"
  return 0
}
ipc() { timeout 2 qs -c ocarina ipc call "$@" 2>/dev/null; }
shell_pid() { systemctl --user show -p MainPID --value ocarinashell 2>/dev/null; }
qml_errors() {   # journal of the shell since $1 (systemd timestamp): QML errors only, without known Qt noise
  journalctl --user -u ocarinashell --since "$1" -o cat --no-pager 2>/dev/null | strip \
    | grep -E 'ERROR|TypeError|ReferenceError|is not installed|unavailable|Failed to load|Binding loop|deprecated' \
    | grep -vE 'Could not register app ID|QWaylandTextInputv3' | sort | uniq -c | sort -rn | head -n 5
}

# ── checks ───────────────────────────────────────────────────────────────────────────────────────────────────────
c_versions() {
  local p v obj="{}"
  for p in niri quickshell qt6-base qt6-declarative ghostty neovim fish mesa linux-cachyos linux-cachyos-lts limine \
           plymouth pipewire wireplumber freerdp systemd; do
    v="$(pacman -Q "$p" 2>/dev/null | awk '{print $2}')"
    [[ -n "$v" ]] && obj="$(jq -c --arg k "$p" --arg v "$v" '. + {($k): $v}' <<<"$obj")"
  done
  obj="$(jq -c --arg v "$(uname -r)" '. + {running_kernel: $v}' <<<"$obj")"
  printf '%s\n' "$obj" > "$tmp/versions.json"
}

c_niri() {
  have niri || { rec niri fail "niri no está instalado"; return; }
  local out rc=0
  out="$(timeout 10 niri validate 2>&1 | strip)" || rc=$?
  if ((rc)); then   # niri prints miette diagnostics: keep the «Error: × …» lines and the [file:line:col] locations
    rec niri fail "niri validate: $(grep -E '^Error:|\[[^]]+:[0-9]+:[0-9]+\]' <<<"$out" | sed -E 's/^Error: *[^[:alnum:]]* *//; s/^[^[]*\[/[/' \
                                     | tail -n 3 | tr '\n' ' ' | tr -s ' ')"
  elif grep -qi deprecat <<<"$out"; then rec niri warn "niri validate: opciones obsoletas · $(grep -i deprecat <<<"$out" | head -n 2 | tr '\n' ' ')"
  else rec niri ok "niri validate sin errores ni deprecaciones"; fi
  [[ -S "${NIRI_SOCKET:-}" ]] && timeout 2 niri msg version >/dev/null 2>&1 \
    && rec niri-ipc ok "el socket de niri responde" || rec niri-ipc fail "el socket de niri no responde (NIRI_SOCKET=${NIRI_SOCKET:-vacío})"
}

c_shell() {
  local since st fails errs i
  if ((active)); then
    since="$(date '+%Y-%m-%d %H:%M:%S')"
    systemctl --user reset-failed ocarinashell ocarinashell-safe >/dev/null 2>&1
    systemctl --user restart ocarinashell 2>/dev/null || { rec shell fail "systemctl --user restart ocarinashell falló"; return; }
    st=""
    for i in $(seq 1 25); do   # 5 s
      sleep 0.2
      st="$(ipc shell status | tail -n1)"; [[ "$st" == \{* ]] && break
    done
    [[ "$st" == \{* ]] || { rec shell fail "la shell reiniciada no responde por IPC en 5 s"; return; }
    rec shell ok "reinicio de la shell: responde en $((i * 200)) ms"
    sleep 1.5   # late bindings and the first frame of every module
  else
    systemctl --user is-active -q ocarinashell || {
      if systemctl --user is-active -q ocarinashell-safe; then rec shell fail "MODO SEGURO: la shell normal no arranca"
      else rec shell fail "ocarinashell.service no está activo"; fi
      return; }
    since="$(systemctl --user show -p ActiveEnterTimestamp --value ocarinashell)"
    st="$(ipc shell status | tail -n1)"
    [[ "$st" == \{* ]] && rec shell ok "la shell responde por IPC (versión $(jq -r .version <<<"$st"))" \
      || { rec shell fail "la shell no responde por IPC"; return; }
  fi
  fails="$(ipc shell status | tail -n1 | jq -r '.failures | to_entries[] | "\(.key): \(.value | split("\n")[0])"' 2>/dev/null)"
  [[ -z "$fails" ]] && rec shell-modules ok "todos los módulos y servicios cargados" \
    || rec shell-modules fail "no disponible · $(head -n 3 <<<"$fails" | tr '\n' ' ')"
  errs="$(qml_errors "$since")"
  [[ -z "$errs" ]] && rec shell-journal ok "journal de la shell sin errores QML ni avisos de deprecación" \
    || rec shell-journal fail "journal: $(head -n 3 <<<"$errs" | sed 's/^ *//' | tr '\n' ' ' | cut -c1-300)"
}

c_ipc() {
  # every target the repo declares must exist, and the read-only getters must answer
  local want have_t missing="" f bad="" out
  want="$(grep -oE 'target: "[a-z]+"' "$repo/shell/ipc/Ipc.qml" | cut -d'"' -f2 | sort -u)"
  have_t="$(timeout 3 qs -c ocarina ipc show 2>/dev/null | awk '/^target /{print $2}' | sort -u)"
  [[ -n "$have_t" ]] || { rec ipc fail "qs ipc show no responde"; return; }
  missing="$(comm -23 <(echo "$want") <(echo "$have_t") | tr '\n' ' ')"
  [[ -z "${missing// }" ]] && rec ipc-targets ok "$(wc -l <<<"$want") destinos IPC registrados" \
    || rec ipc-targets fail "faltan destinos IPC: $missing"
  for f in "shell version" "lock state" "idle status" "theme get" "session status" "focus status" "shinobi status" \
           "oni status" "nameraka status" "fune status" "brightness list" "kura count" "displays list" "iro status" \
           "power isOpen" "hiroba isOpen" "lock isLocked" "updates status" "audio status"; do
    # shellcheck disable=SC2086  # "target function" on purpose
    out="$(ipc $f)" || { bad+="$f · "; continue; }
    [[ -n "$out" ]] || bad+="$f (vacío) · "
  done
  [[ -z "$bad" ]] && rec ipc-calls ok "19 funciones inocuas responden" || rec ipc-calls fail "no responden: ${bad% · }"
}

c_lock() {
  ((active)) || return 0
  local s i
  s="$(ipc lock state)"
  if [[ "$(jq -r .active <<<"$s" 2>/dev/null)" == true ]]; then
    rec lock-test warn "la pantalla está bloqueada (o en prueba): no se abre el modo prueba"; return
  fi
  ipc lock test >/dev/null || { rec lock-test fail "lock test no responde"; return; }
  for i in $(seq 1 15); do sleep 0.2; [[ "$(ipc lock state | jq -r '.active and .test' 2>/dev/null)" == true ]] && break; done
  [[ "$(ipc lock state | jq -r '.active and .test' 2>/dev/null)" == true ]] || { rec lock-test fail "el modo prueba del bloqueo no se abrió en 3 s"; ipc lock cancel >/dev/null; return; }
  sleep 0.4
  ipc lock cancel >/dev/null
  for i in $(seq 1 15); do sleep 0.2; [[ "$(ipc lock state | jq -r .active 2>/dev/null)" == false ]] && break; done
  [[ "$(ipc lock state | jq -r .active 2>/dev/null)" == false ]] && rec lock-test ok "el bloqueo en modo prueba abre y cierra" \
    || rec lock-test fail "el modo prueba del bloqueo no se cerró"
}

c_terminal() {
  local out
  if have ghostty; then
    out="$(timeout 10 ghostty +validate-config 2>&1)" && rec ghostty ok "Ghostty: config válida" \
      || rec ghostty fail "Ghostty: $(head -n 2 <<<"$out" | tr '\n' ' ')"
  else rec ghostty fail "falta ghostty"; fi
  if have fish; then
    local f bad=""
    for f in "$HOME/.config/fish/config.fish" "$HOME"/.config/fish/conf.d/*.fish "$HOME"/.config/fish/functions/*.fish; do
      [[ -f "$f" ]] || continue
      fish -n "$f" 2>/dev/null || bad+="$(basename "$f") "
    done
    [[ -z "$bad" ]] && rec fish ok "fish -n: toda la config se analiza bien" || rec fish fail "fish -n falla en: $bad"
  else rec fish fail "falta fish"; fi
  if have starship; then
    timeout 3 starship prompt >/dev/null 2>&1 && rec starship ok "starship prompt" || rec starship fail "starship prompt falla"
  else rec starship warn "falta starship"; fi
}

c_nvim() {
  have nvim || { rec nvim warn "falta neovim"; return; }
  local out rc=0
  out="$(cd "$tmp" && timeout 15 nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 300)" 2>&1 | strip)" || rc=$?
  if ((rc)) || grep -qE '(^|[^a-z])E[0-9]{2,4}:|Error (detected|executing)|stack traceback' <<<"$out"; then
    rec nvim fail "Neovim arranca con errores: $(grep -m2 -E 'E[0-9]+:|Error|traceback' <<<"$out" | tr '\n' ' ' | cut -c1-200)"
  else
    rec nvim ok "Neovim arranca sin errores (headless)"
  fi
}

c_units() {
  local u bad="" failed
  for u in ocarinashell pipewire wireplumber pipewire-pulse xdg-desktop-portal; do
    systemctl --user is-active -q "$u" 2>/dev/null && continue
    # started on demand: pipewire-pulse by its socket, the portal by D-Bus. Inactive and not failed is how they wait
    # for their first client (Mamori's check 2 min after a boot flagged pipewire-pulse, fase 17)
    if ! systemctl --user is-failed -q "$u" 2>/dev/null && { systemctl --user is-active -q "$u.socket" 2>/dev/null \
        || [[ -n "$(systemctl --user show -p BusName --value "$u" 2>/dev/null)" ]]; }; then
      continue
    fi
    bad+="$u "
  done
  [[ -z "$bad" ]] && rec units ok "unidades de la sesión activas (shell, PipeWire, WirePlumber, portales)" \
    || rec units fail "unidades inactivas: $bad"
  failed="$(systemctl --user --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
  if [[ -z "${failed// }" ]]; then rec units-failed ok "ninguna unidad de usuario fallida"
  elif grep -q 'ocarina' <<<"$failed"; then rec units-failed fail "unidades de OcarinaShell fallidas: $failed"
  else rec units-failed warn "unidades de usuario fallidas: $failed"; fi
  failed="$(systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
  [[ -z "${failed// }" ]] && rec units-system ok "ninguna unidad del sistema fallida" || rec units-system warn "unidades del sistema fallidas: $failed"
}

c_bus() {
  local pid owner
  pid="$(shell_pid)"
  owner="$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^PID=//p')"
  if [[ -n "$owner" && "$owner" == "$pid" ]]; then rec notifications ok "la shell es dueña de org.freedesktop.Notifications"
  else rec notifications fail "org.freedesktop.Notifications es de PID ${owner:-nadie} (la shell es $pid)"; fi
  # Quickshell's polkit agent: its failure would be in Health; no foreign agent may run beside it
  if pgrep -u "$UID" -f 'polkit-(gnome|kde|mate)-authentication-agent|lxpolkit|hyprpolkitagent' >/dev/null; then
    rec polkit fail "hay otro agente de polkit en marcha"
  elif ipc shell status | tail -n1 | jq -e '.failures | keys | map(test("olkit")) | any' >/dev/null 2>&1; then
    rec polkit fail "el agente de polkit de la shell no cargó"
  else rec polkit ok "agente de polkit: el de la shell"; fi
  busctl --user status org.freedesktop.portal.Desktop >/dev/null 2>&1 && rec portals ok "xdg-desktop-portal responde" \
    || rec portals fail "xdg-desktop-portal no está en el bus"
}

c_fonts() {
  local f bad=""
  for f in "JetBrainsMono Nerd Font" "Noto Sans CJK JP" "Geist" "Zen Kaku Gothic New" "Shippori Mincho B1" "Yuji Syuku" \
           "Unbounded" "Material Symbols Rounded"; do
    fc-list ":family=$f" family 2>/dev/null | grep -q . || bad+="$f · "
  done
  [[ -z "$bad" ]] && rec fonts ok "las 8 fuentes de marca están" || rec fonts fail "faltan fuentes: ${bad% · }"
}

c_theme() {
  local cur out
  cur="$(python3 "$repo/bin/ocarina-theme" current 2>/dev/null | cut -d' ' -f1)"
  [[ -n "$cur" ]] || { rec theme warn "ningún tema aplicado"; return; }
  out="$(timeout 20 python3 "$repo/bin/ocarina-theme" apply "$cur" --dry-run 2>&1)" && rec theme ok "ocarina-theme apply $cur --dry-run" \
    || rec theme fail "ocarina-theme --dry-run: $(tail -n 2 <<<"$out" | tr '\n' ' ')"
}

c_boot() {
  local helper=/usr/local/libexec/ocarina-maint j bad
  if [[ ! -x "$helper" ]] || ! j="$(timeout 20 sudo -n "$helper" boot-check 2>/dev/null)"; then
    rec boot warn "sin ayudante ocarina-maint (o sin su regla de sudo): arranque sin comprobar"; return
  fi
  bad=""
  [[ "$(jq -r .limineConf <<<"$j")" == true ]] || bad+="no se lee /boot/limine.conf · "
  [[ "$(jq -r .limineBlock <<<"$j")" == true ]] || bad+="falta el bloque del tema en limine.conf · "
  [[ "$(jq -r .ltsEntry <<<"$j")" == true ]] || bad+="no hay entrada del kernel LTS · "
  [[ "$(jq -r '.initramfs | length' <<<"$j")" -gt 0 ]] || bad+="no encuentro initramfs en el menú · "
  bad+="$(jq -r '.initramfs[] | select(.plymouth | not) | "sin tema Plymouth: \(.path) · "' <<<"$j" | tr -d '\n')"
  [[ -z "$bad" ]] && rec boot ok "Limine con su tema y LTS; tema Plymouth en $(jq -r '.initramfs | length' <<<"$j") initramfs" \
    || rec boot fail "${bad% · }"
}

c_fune() {
  local fune="$HOME/.local/bin/ocarina-fune" line fails="" warns=""
  if [[ ! -x "$fune" ]] || ! have podman; then rec fune ok "Fune sin instalar (opcional)"; return; fi
  while IFS= read -r line; do
    case "$line" in
      "FALLO "*) fails+="${line#FALLO } · " ;;
      "aviso "*) warns+="${line#aviso } · " ;;
    esac
  done < <(timeout 25 "$fune" smoke 2>/dev/null)
  if [[ -n "$fails" ]]; then rec fune fail "Fune: ${fails% · }"
  elif [[ -n "$warns" ]]; then rec fune warn "Fune: ${warns% · }"
  else rec fune ok "Fune: podman, FreeRDP y la VM en orden (sin arrancarla)"; fi
}

c_nameraka() {
  local nk="$HOME/.local/libexec/ocarinashell/nameraka" j code
  [[ -x "$nk" ]] || { rec nameraka warn "Nameraka sin compilar"; return; }
  j="$(timeout 10 "$nk" self-test --json 2>/dev/null | tail -n1)"
  code="$(jq -r .code <<<"$j" 2>/dev/null)"
  if [[ "$(jq -r .available <<<"$j" 2>/dev/null)" == true ]]; then rec nameraka ok "nameraka self-test"
  elif [[ "$code" =~ ^1[3-5]$ ]]; then rec nameraka ok "nameraka: $(jq -r .reason <<<"$j") (código $code, no cuenta)"
  else rec nameraka warn "nameraka self-test: $(jq -r '.reason // "sin respuesta"' <<<"$j" 2>/dev/null) (código ${code:-?}) → playbook de 滑"; fi
}

# 蛇 Snake and 読 Yomu (fase 15): optional pieces → warnings only (Mamori's playbook), never a rollback by themselves.
# Passive: no model is loaded; llama.cpp must still start and see the GPU through Vulkan after an update.
c_snake() {
  local sn="$HOME/.local/bin/ocarina-snake" j devs
  [[ -x "$sn" ]] || { rec snake ok "Snake sin instalar (opcional)"; return; }
  j="$(timeout 10 "$sn" smoke 2>/dev/null | tail -n1)"
  if [[ "$(jq -r .ok <<<"$j" 2>/dev/null)" != true ]]; then
    rec snake warn "Snake: $(jq -r '.problems | join(" · ")' <<<"$j" 2>/dev/null || echo "sin respuesta")"; return
  fi
  if [[ "$(jq -r '.snake.backend // "vulkan"' "${XDG_CONFIG_HOME:-$HOME/.config}/ocarinashell/settings.json" 2>/dev/null)" == vulkan ]] \
      && have llama-bench; then
    devs="$(timeout 15 llama-bench --list-devices 2>/dev/null | grep -c '^ *Vulkan')"
    ((devs > 0)) || { rec snake warn "Snake: llama.cpp no ve la GPU por Vulkan (¿ggml-vulkan o Mesa?)"; return; }
  fi
  rec snake ok "Snake: tareas, lista blanca, modelo y llama.cpp con Vulkan en orden (sin cargarlo)"
}
c_yomu() {
  local langs
  have tesseract || { rec yomu warn "Yomu: falta tesseract"; return; }
  langs="$(tesseract --list-langs 2>/dev/null)"
  for l in jpn jpn_vert spa eng; do
    grep -qx "$l" <<<"$langs" || { rec yomu warn "Yomu: falta tesseract-data-$l"; return; }
  done
  have slurp && have grim || { rec yomu warn "Yomu: falta slurp o grim"; return; }
  rec yomu ok "Yomu: tesseract (jpn, jpn_vert, spa, eng), slurp y grim"
}

c_extra() {   # scripts/smoke.d and ~/.config/ocarinashell/smoke.d: one JSON check per line
  local d f line n=0
  for d in "$repo/scripts/smoke.d" "${XDG_CONFIG_HOME:-$HOME/.config}/ocarinashell/smoke.d"; do
    [[ -d "$d" ]] || continue
    for f in "$d"/*; do
      [[ -x "$f" && -f "$f" ]] || continue
      n=$((n + 1))
      while IFS= read -r line; do
        jq -e 'has("id") and has("level") and (.level | test("^(ok|warn|fail)$"))' >/dev/null 2>&1 <<<"$line" \
          && jq -c '. + {ms: (.ms // 0)}' <<<"$line" >> "$tmp/r.extra-$n" \
          || rec "extra-$n" fail "$(basename "$f"): salida no válida «${line:0:80}»"
      done < <(timeout 20 "$f" 2>/dev/null)
    done
  done
}

# ── run: the visible ones first and alone (a restarting shell must not be probed half-way), the rest in parallel ──
c_versions
if ((active)); then timed shell c_shell; timed lock-test c_lock; fi
((active)) || timed shell c_shell &
timed niri c_niri &
timed ipc c_ipc &
timed ghostty c_terminal &
timed nvim c_nvim &
timed units c_units &
timed notifications c_bus &
timed fonts c_fonts &
timed theme c_theme &
timed boot c_boot &
timed fune c_fune &
timed nameraka c_nameraka &
timed snake c_snake &
timed yomu c_yomu &
timed extra c_extra &
wait

dur=$(( ($(date +%s%N) - t_start) / 1000000 ))
mkdir -p "$state"
cat "$tmp"/r.* 2>/dev/null | jq -s --arg mode "$mode" --argjson d "$dur" --slurpfile v "$tmp/versions.json" \
  '{at: (now | floor), mode: $mode, durationMs: $d, ok: (map(select(.level == "fail")) | length == 0),
    failures: (map(select(.level == "fail")) | length), warnings: (map(select(.level == "warn")) | length),
    versions: ($v[0] // {}), checks: sort_by(.id)}' > "$report.tmp" && mv -f "$report.tmp" "$report"

if ((json)); then cat "$report"
else
  jq -r --argjson q "$quiet" '.checks[] | select($q == 0 or .level != "ok")
    | (if .level == "ok" then "  \u001b[32m✓\u001b[0m" elif .level == "warn" then "  \u001b[33m⚠\u001b[0m" else "  \u001b[31m✗\u001b[0m" end)
      + " " + .msg + (if .ms > 400 then " \u001b[2m(" + ((.ms / 100 | floor) / 10 | tostring) + " s)\u001b[0m" else "" end)' "$report"
  jq -r '"\n" + (if .ok then "\u001b[32mPruebas de humo superadas\u001b[0m" else "\u001b[31m\(.failures) fallo(s)\u001b[0m" end)
         + " · \(.warnings) aviso(s) · \(.durationMs / 100 | floor | . / 10) s · modo \(.mode)"' "$report"
fi
[[ "$(jq -r .ok "$report")" == true ]]
