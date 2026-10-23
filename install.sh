#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2329   # cleanup and the checks are called through traps and check_line "$@"
# ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
#  OcarinaShell · オカリナシェル — instalador de los dotfiles · Created by Ayoub
#
#    git clone https://github.com/ayoubtahriouixd/ocarinashell ~/ocarinashell
#    cd ~/ocarinashell && ./install.sh            (./install.sh --demo: todo el recorrido sin cambiar nada)
#
#  Qué hace, con tu permiso en cada paso: comprueba el equipo, instala los paquetes de los grupos que elijas
#  (scripts/paquetes.txt), las fuentes, enlaza los dotfiles (scripts/install.sh, con copia de lo que ya tuvieras),
#  copia los ficheros de root (scripts/install-system.sh), aplica el tema que elijas, activa los servicios y pasa
#  `ocarina doctor`. Antes de tocar el sistema hace un snapshot de snapper si lo hay.
#  Qué NO hace: tocar /boot, el kernel, PAM ni el greeter (eso va en scripts/root/, a mano), ni reiniciar.
# ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(sed -n 's/^version="\(.*\)"/\1/p' "$REPO/bin/ocarina" 2>/dev/null)"
PKGS="$REPO/scripts/paquetes.txt"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/ocarinashell/install.log"
DEMO=0 YES=0 PLAIN=0 THEME="" SKIP_PKGS=0 SKIP_SYSTEM=0 K="" K2="" FAILED=0

usage() {
  cat <<'EOF'
OcarinaShell · instalador

  ./install.sh [opciones]

  --demo            el recorrido completo, animaciones incluidas, sin cambiar nada
  --tema <id>       kurenai · kohaku · sumi · ai · matcha · yozakura · shinobi (sin preguntar)
  --si              sin preguntas: grupos por defecto y el tema elegido (o Kurenai)
  --sin-paquetes    no instala paquetes (solo dotfiles, fuentes, sistema y tema)
  --sin-sistema     no copia los ficheros de root (polkit, ayudantes)
  --simple          sin animaciones (también con NO_MOTION=1, sin terminal o con TERM=dumb)
  -h, --help        esta ayuda

El registro completo queda en ~/.cache/ocarinashell/install.log.
EOF
}
while (($#)); do
  case "$1" in
    --demo|--dry-run) DEMO=1 ;;
    --tema|--theme) THEME="${2:-}"; shift ;;
    --si|--yes|-y) YES=1 ;;
    --sin-paquetes) SKIP_PKGS=1 ;;
    --sin-sistema) SKIP_SYSTEM=1 ;;
    --simple|--plain) PLAIN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "opción desconocida: $1 (./install.sh --help)" >&2; exit 2 ;;
  esac
  shift
done
[[ -t 1 && -t 0 && "${TERM:-dumb}" != dumb && -z "${NO_MOTION:-}" ]] || PLAIN=1
mkdir -p "${LOG%/*}"
: > "$LOG"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# ── colours (Kurenai) ─────────────────────────────────────────────────────────────────────────────────────────
BG="11;10;12" TX="244;239;230" MU="170;163;155" DI="135;128;121" RED="230;0;51" REDL="255;31;79" GOLD="230;180;34"
SAKURA="243;127;143" OK="104;190;141"
fg() { printf '\e[38;2;%sm' "$1"; }
bgc() { printf '\e[48;2;%sm' "$1"; }
R=$'\e[0m' B=$'\e[1m'
at() { printf '\e[%d;%dH' "$1" "$2"; }

ROWS=40 COLS=120
size() { local s; s="$(stty size 2>/dev/null)" && read -r ROWS COLS <<<"$s"; ((ROWS < 24)) && ROWS=24; ((COLS < 80)) && COLS=80; }

# visible width: kana, CJK ideographs and full-width forms count 2 columns (by code point: bash regex ranges
# over multibyte characters fail with «Invalid collation character» in some locales)
vwidth() {
  local s="$1" n=0 i cp
  for ((i = 0; i < ${#s}; i++)); do
    printf -v cp '%d' "'${s:i:1}"
    if (((cp >= 0x3000 && cp <= 0x9fff) || (cp >= 0xff00 && cp <= 0xff60))); then n=$((n + 2)); else n=$((n + 1)); fi
  done
  echo "$n"
}
rep() { local out; printf -v out '%*s' "$2" ''; printf '%s' "${out// /$1}"; }   # rep <char> <n> (tr breaks UTF-8)
center() { local w; w="$(vwidth "$2")"; at "$1" $(((COLS - w) / 2 + 1)); printf '%s' "$2"; }

# a key without blocking (returns 0 if one came): every animation can be skipped
key() { IFS= read -rsn1 -t "${1:-0.001}" K 2>/dev/null; }
pause() { key "$1" && return 1; return 0; }        # pause <s>: false if a key was pressed (skip)

cleanup() {
  [[ -n "${KEEP_SUDO:-}" ]] && kill "$KEEP_SUDO" 2>/dev/null
  ((PLAIN)) || printf '\e[0m\e[?25h\e[?1049l'
  stty echo 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT TERM

paint_bg() {        # paint_bg "<r;g;b>": the whole screen in one colour
  local line; printf -v line '%*s' "$COLS" ''
  bgc "$1"; local r; for ((r = 1; r <= ROWS; r++)); do at "$r" 1; printf '%s' "$line"; done
}

# ── 1 · the opening: a red sun, clouds crossing it, the name ink by ink ─────────────────────────────────────────
sun_frame() {       # sun_frame <radius in half-rows> <cloud drift>
  local rad=$1 off=$2 cx=$((COLS / 2)) cy=$((ROWS * 2 * 34 / 100)) top bot x y py out c inT inB k r2 b0 b1 b2
  top=$(((cy - rad) / 2)); bot=$(((cy + rad) / 2 + 1)); r2=$((rad * rad + rad))      # (r + ½)²: no lone pixels
  # the streaks (pixel rows) of the Kurenai wallpaper across the lower half, each drifting at its own pace
  b0=$((cy + rad * 3 / 10)); b1=$((cy + rad * 5 / 10)); b2=$((cy + rad * 7 / 10))
  for ((y = top; y <= bot; y++)); do
    out=""
    for ((x = cx - rad - 1; x <= cx + rad + 1; x++)); do
      inT=0; inB=0
      for k in 0 1; do
        py=$((2 * y + k))
        (((x - cx) * (x - cx) + (py - cy) * (py - cy) <= r2)) || continue
        if ((py == b0 && x > cx - rad + off % 9 && x < cx + rad * 7 / 10 + off % 9)) ||
           ((py == b1 && x > cx - rad * 8 / 10 - off % 7 && x < cx + rad - off % 7)) ||
           ((py == b2 && x > cx - rad * 6 / 10 + off % 5 && x < cx + rad * 9 / 10 + off % 5)); then continue; fi
        if ((k == 0)); then inT=1; else inB=1; fi
      done
      # gradient: brighter at the top of the sun
      k=$((y - top)); ((k > 30)) && k=30
      c="$((255 - k * 3));$((40 - k));$((70 - k))"
      if ((inT && inB)); then out+=$'\e[38;2;'"$c"$'m█'
      elif ((inT)); then out+=$'\e[38;2;'"$c"$'m▀'
      elif ((inB)); then out+=$'\e[38;2;'"$c"$'m▄'
      else out+=' '; fi
    done
    at $((y + 1)) $((cx - rad)); printf '\e[48;2;%sm%s' "$BG" "$out"
  done
}

opening() {
  paint_bg "$BG"
  local maxr=$((ROWS * 2 * 20 / 100)) r f
  ((maxr > COLS / 5)) && maxr=$((COLS / 5))
  for ((r = 2; r <= maxr; r += 2)); do sun_frame "$r" "$r"; pause 0.02 || break; done
  for ((f = 0; f < 18; f++)); do sun_frame "$maxr" $((maxr + f)); pause 0.04 || break; done
  sun_frame "$maxr" $((maxr + 18))
  # the name: each letter rises from the ink to paper; SHELL in red
  local word="O C A R I N A S H E L L" row=$((ROWS * 62 / 100)) col i ch step
  col=$(((COLS - ${#word}) / 2 + 1))
  for ((i = 0; i < ${#word}; i++)); do
    ch="${word:i:1}"; [[ "$ch" == " " ]] && continue
    for step in 60 140 230; do
      at "$row" $((col + i)); bgc "$BG"
      if ((i >= 14)); then printf '\e[38;2;%d;0;%dm%s' $((step + 25)) $((step / 5)) "$ch"
      else printf '\e[38;2;%d;%d;%dm%s' "$step" $((step - 4)) $((step - 12)) "$ch"; fi
      pause 0.012 || { i=99; break; }
    done
  done
  at "$row" "$col"; printf '%s%s%s' "$(fg "$TX")$B" "O C A R I N A " "$(fg "$RED")S H E L L$R$(bgc "$BG")"
  pause 0.25
  bgc "$BG"; fg "$MU"; center $((row + 2)) "オ カ リ ナ シ ェ ル"
  pause 0.35
  fg "$DI"; center $((row + 4)) "tu escritorio · niri + Quickshell · CachyOS · Created by Ayoub"
  if ((DEMO)); then fg "$GOLD"; center $((row + 5)) "modo demostración: no se cambia nada"; fi
  fg "$MU"; center $((ROWS - 2)) "Intro para empezar  ·  q para salir"
  if ((!YES)); then IFS= read -rsn1 K; [[ "$K" == q ]] && exit 0; fi
}

# ── 2 · the checks ──────────────────────────────────────────────────────────────────────────────────────────────
WARN=0
header() {          # header <kanji> <title>
  paint_bg "$BG"
  at 2 4; printf '%s%s %s%s' "$(fg "$RED")$B" "$1" "$(fg "$TX")" "$2"
  at 2 $((COLS - 26)); printf '%sオカリナシェル · %s%s' "$(fg "$DI")" "$( ((DEMO)) && echo demo || echo "${VERSION:-2.0.0}")" "$R$(bgc "$BG")"
  at 3 4; fg "$DI"; rep ─ $((COLS - 7))
}
check_line() {      # check_line <row> <label> <command…>: dots that breathe while it runs, then ✓ / ⚠
  local row=$1 label=$2 f=0 dots=("·  " "·· " "···" " ··" "  ·" "   "); shift 2
  "$@" >>"$LOG" 2>&1 & local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    at "$row" 6; printf '%s%s %s%s\e[K' "$(fg "$RED")" "${dots[f % 6]}" "$(fg "$MU")" "$label"; f=$((f + 1)); sleep 0.07
  done
  # the same 4 columns before the label as the dots, so nothing of the running line is left behind
  if wait "$pid"; then at "$row" 6; printf '%s ✓  %s%s\e[K' "$(fg "$OK")" "$(fg "$TX")" "$label"
  else at "$row" 6; printf '%s ⚠  %s%s\e[K' "$(fg "$GOLD")" "$(fg "$TX")" "$label"; WARN=$((WARN + 1)); fi
}
os_ok() { grep -qiE '^ID(_LIKE)?=.*(arch|cachyos)' /etc/os-release; }
net_ok() { curl -fsS --max-time 6 -o /dev/null https://archlinux.org; }
disk_ok() { (($(df -Pk "$HOME" | awk 'NR==2{print $4}') > 8000000)); }
gpu_ok() { ls /dev/dri/renderD* >/dev/null 2>&1; }
sudo_ok() { command -v sudo >/dev/null; }
checks() {
  header "確" "Comprobar el equipo"
  local r=6
  check_line $r "Arch Linux o CachyOS" os_ok; r=$((r + 2))
  check_line $r "Conexión a internet" net_ok; r=$((r + 2))
  check_line $r "Más de 8 GB libres en tu carpeta personal" disk_ok; r=$((r + 2))
  check_line $r "Gráfica con renderizado (DRM)" gpu_ok; r=$((r + 2))
  check_line $r "sudo disponible" sudo_ok; r=$((r + 2))
  check_line $r "Sesión Wayland o TTY" true; r=$((r + 3))
  at $r 6
  if ((WARN)); then printf '%s%d aviso(s): puedes seguir, pero algo podría no funcionar.' "$(fg "$GOLD")" "$WARN"
  else printf '%sTodo listo.' "$(fg "$OK")"; fi
  pause 1.2
}

# ── 3 · the theme: seven cards with their real colours; the whole screen takes the one you point at ─────────────
THEMES=()
load_themes() {
  mapfile -t THEMES < <(python3 -I - "$REPO/assets/data/themes" <<'PY'
import json, pathlib, sys
order = ["kurenai", "kohaku", "sumi", "ai", "matcha", "yozakura", "shinobi"]
def rgb(h):
    h = h.lstrip("#")[:6]
    return ";".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))
for tid in order:
    p = pathlib.Path(sys.argv[1]) / f"{tid}.json"
    if not p.exists():
        continue
    t = json.loads(p.read_text())
    c = t["colors"]
    print("|".join([tid, t["name"], t["kanji"], t.get("mode", "dark"), rgb(c["bg"]), rgb(c["surface1"]),
                    rgb(c["surface3"]), rgb(c["accent"]), rgb(c["text"]), rgb(c["textMuted"]), t.get("description", "")]))
PY
)
}
theme_card() {      # theme_card <index> <selected 0|1> <row> <col> <screen bg>
  local i=$1 sel=$2 row=$3 col=$4 sbg=$5 id name kanji mode bg s1 s3 acc tx mu desc w=15 r edge
  IFS='|' read -r id name kanji mode bg s1 s3 acc tx mu desc <<<"${THEMES[i]}"
  edge="$( ((sel)) && echo "$acc" || echo "$s3")"
  ((sel)) && row=$((row - 1))
  at "$row" "$col"; printf '%s%s╭%s╮' "$(bgc "$sbg")" "$(fg "$edge")" "$(rep ─ $((w - 2)))"
  for ((r = 1; r <= 6; r++)); do
    at $((row + r)) "$col"; printf '%s%s│%s' "$(bgc "$sbg")" "$(fg "$edge")" "$(bgc "$bg")"
    case $r in
      # every row is exactly w − 2 columns wide (vwidth: kanji and «ō» are not one byte each)
      1) printf '%s %s%*s' "$(fg "$acc")$B" "$kanji" $((w - 3 - $(vwidth "$kanji"))) '' ;;
      2) printf '%s %s%*s' "$(fg "$tx")$B" "$name" $((w - 3 - $(vwidth "$name"))) '' ;;
      3) local m; m="$( [[ $mode == light ]] && echo claro || echo oscuro)"
         printf '%s %s%*s' "$(fg "$mu")" "$m" $((w - 3 - ${#m})) '' ;;
      4) printf '%*s' $((w - 2)) '' ;;
      5) printf ' %s██ %s██ %s██ %s██ ' "$(fg "$acc")" "$(fg "$tx")" "$(fg "$s3")" "$(fg "$s1")" ;;
      6) printf '%*s' $((w - 2)) '' ;;
    esac
    printf '%s%s│' "$R$(bgc "$sbg")" "$(fg "$edge")"
  done
  at $((row + 7)) "$col"; printf '%s%s╰%s╯%s' "$(bgc "$sbg")" "$(fg "$edge")" "$(rep ─ $((w - 2)))" "$R"
  ((sel)) || { at $((row - 1)) "$col"; printf '%s%*s' "$(bgc "$sbg")" "$w" ''; }
  ((sel)) && { at $((row + 8)) "$col"; printf '%s%*s' "$(bgc "$sbg")" "$w" ''; }
}
pick_theme() {
  load_themes
  ((${#THEMES[@]})) || { THEME=kurenai; return; }
  if [[ -n "$THEME" ]] || ((YES)); then THEME="${THEME:-kurenai}"; return; fi
  local sel=0 n=${#THEMES[@]} i col0 row id bg tx mu desc
  while true; do
    IFS='|' read -r id _ _ _ bg _ _ _ tx mu desc <<<"${THEMES[sel]}"
    paint_bg "$bg"
    at 2 4; printf '%s彩 %sElige tu tema%s' "$(fg "$RED")$B" "$(fg "$tx")" "$R$(bgc "$bg")"
    at 3 4; printf '%s%s' "$(fg "$mu")" "$desc"
    row=$((ROWS / 2 - 4)); col0=$(((COLS - n * 17) / 2 + 1))
    for ((i = 0; i < n; i++)); do theme_card "$i" $((i == sel)) "$row" $((col0 + i * 17)) "$bg"; done
    at $((ROWS - 2)) 4; printf '%s← →  elegir   ·   Intro  aplicar   ·   se puede cambiar luego en Ajustes › Apariencia' "$(bgc "$bg")$(fg "$mu")"
    IFS= read -rsn1 K
    case "$K" in
      $'\e') read -rsn2 -t 0.01 K2; [[ "$K2" == "[C" ]] && sel=$(((sel + 1) % n)); [[ "$K2" == "[D" ]] && sel=$(((sel + n - 1) % n)) ;;
      l) sel=$(((sel + 1) % n)) ;; h) sel=$(((sel + n - 1) % n)) ;;
      ""|" ") THEME="$id"; return ;;
      q) exit 0 ;;
    esac
  done
}

# ── 4 · the optional parts: a checklist (space toggles) ─────────────────────────────────────────────────────────
PGROUPS=() GTITLE=() GDESC=() GON=() GREQ=()
load_groups() {
  local line g t d req
  while IFS= read -r line; do
    [[ "$line" =~ ^\[([a-z]+)\](\*?)\ (.*)$ ]] || continue
    g="${BASH_REMATCH[1]}"; req="${BASH_REMATCH[2]}"; t="${BASH_REMATCH[3]%% · *}"; d="${BASH_REMATCH[3]#* · }"
    PGROUPS+=("$g"); GTITLE+=("$t"); GDESC+=("$d"); GREQ+=("$( [[ -n $req ]] && echo 1 || echo 0)")
    # on by default: the required ones, Snake and Mamori (light), and AUR only with paru
    case "$g" in
      base|terminal|snake|mamori) GON+=(1) ;;
      aur) GON+=("$(command -v paru >/dev/null && echo 1 || echo 0)") ;;
      *) GON+=(0) ;;
    esac
  done <"$PKGS"
}
group_pkgs() { awk -v g="[$1]" '$1 ~ /^\[/ {on = index($1, g) == 1; next} on && !/^#/ && NF {print}' "$PKGS" | tr '\n' ' '; }
pick_groups() {
  load_groups
  ((SKIP_PKGS || YES)) && return
  local sel=0 n=${#PGROUPS[@]} i r mark
  header "包" "Qué instalar"
  at 5 6; printf '%s↑ ↓ moverse · Espacio marcar · Intro seguir. Lo marcado con 必 va siempre.' "$(fg "$MU")"
  while true; do
    for ((i = 0; i < n; i++)); do
      r=$((7 + i * 2))
      # every mark two columns wide (必 is a wide character)
      if ((GREQ[i])); then mark="$(fg "$GOLD")必"; elif ((GON[i])); then mark="$(fg "$RED")● "; else mark="$(fg "$DI")○ "; fi
      local bar ttl; bar="$(fg "$BG")"; ttl="$(fg "$TX")"
      if ((i == sel)); then bar="$(fg "$RED")"; ttl="$(fg "$TX")$B"; fi
      at "$r" 6; printf '%s▍ %s %s%s%*s%s%s\e[K' "$bar" "$mark" "$ttl" "${GTITLE[i]}" $((34 - $(vwidth "${GTITLE[i]}"))) '' \
        "$R$(bgc "$BG")$(fg "$MU")" "${GDESC[i]}"
    done
    IFS= read -rsn1 K
    case "$K" in
      $'\e') read -rsn2 -t 0.01 K2; [[ "$K2" == "[A" ]] && sel=$(((sel + n - 1) % n)); [[ "$K2" == "[B" ]] && sel=$(((sel + 1) % n)) ;;
      k) sel=$(((sel + n - 1) % n)) ;; j) sel=$(((sel + 1) % n)) ;;
      " ") ((GREQ[sel])) || GON[sel]=$((1 - GON[sel])) ;;
      "") return ;;
      q) exit 0 ;;
    esac
  done
}

# ── 5 · the installation: a timeline of seals; each step runs in the background with an ink spinner ─────────────
STEPS=() SKANJI=() STITLE=() SSTATE=()
add_step() { STEPS+=("$1"); SKANJI+=("$2"); STITLE+=("$3"); SSTATE+=(wait); }
plan() {
  local repo_pk="" aur_pk="" i
  for ((i = 0; i < ${#PGROUPS[@]}; i++)); do
    ((GON[i] || GREQ[i])) || continue
    if [[ "${PGROUPS[i]}" == aur ]]; then aur_pk+="$(group_pkgs aur)"; else repo_pk+="$(group_pkgs "${PGROUPS[i]}")"; fi
  done
  REPO_PKGS="$repo_pk" AUR_PKGS="$aur_pk"
  command -v snapper >/dev/null && ((!SKIP_SYSTEM || !SKIP_PKGS)) && add_step snapshot "記" "Snapshot del sistema (snapper)"
  ((SKIP_PKGS)) || add_step packages "包" "Paquetes ($(wc -w <<<"$REPO_PKGS") de los repos oficiales)"
  ((SKIP_PKGS)) || [[ -z "${AUR_PKGS// }" ]] || add_step aur "外" "AUR con paru ($(wc -w <<<"$AUR_PKGS"))"
  add_step fonts "字" "Fuentes de la marca"
  add_step links "結" "Dotfiles enlazados (con copia de lo tuyo)"
  ((SKIP_SYSTEM)) || add_step system "系" "Ficheros de sistema (polkit, ayudantes, regla de Mamori)"
  add_step theme "彩" "Tema $(IFS='|' read -r _ n _ <<<"$(printf '%s\n' "${THEMES[@]}" | grep "^$THEME|")"; echo "${n:-$THEME}")"
  add_step services "起" "Servicios de la sesión"
  add_step doctor "診" "Diagnóstico (ocarina doctor)"
}
needs_sudo() { [[ " ${STEPS[*]} " =~ \ (snapshot|packages|system)\  ]]; }

# what each step runs (in demo: a few plausible lines and a pause)
run_step() {
  local s=$1
  if ((DEMO)); then
    local l; for l in "preparando $s…" "comprobando dependencias" "escribiendo en el registro" "listo"; do
      echo "$l"; sleep 0.$((RANDOM % 6 + 3)); done
    return 0
  fi
  case "$s" in
    snapshot) sudo -n snapper -c root create -d "OcarinaShell: antes de instalar" ;;
    packages) # shellcheck disable=SC2086
      sudo -n pacman -S --needed --noconfirm $REPO_PKGS ;;
    aur) # shellcheck disable=SC2086
      paru -S --needed --noconfirm $AUR_PKGS ;;
    fonts) bash "$REPO/scripts/fonts.sh" ;;
    links) bash "$REPO/scripts/install.sh" ;;
    system) sudo -n bash "$REPO/scripts/install-system.sh" &&
            sudo -n bash "$REPO/scripts/root/mamori-sudo.sh" "$USER" ;;
    theme) python3 "$REPO/bin/ocarina-theme" apply "$THEME" ;;
    services) systemctl --user daemon-reload
              systemctl --user enable ocarinashell.service ocarina-mamori.timer 2>&1 || true ;;
    doctor) bash "$REPO/scripts/doctor.sh" --quiet ;;
  esac
}

INK=("◜" "◝" "◞" "◟")
draw_timeline() {   # draw_timeline <active index> <frame>
  local i r a=$1 f=$2 st icon col
  for ((i = 0; i < ${#STEPS[@]}; i++)); do
    r=$((6 + i * 2)); st="${SSTATE[i]}"
    case "$st" in
      wait) icon="$(fg "$DI")○"; col="$(fg "$DI")" ;;
      run) icon="$(fg "$REDL")${INK[f % 4]}"; col="$(fg "$TX")$B" ;;
      ok) icon="$(fg "$RED")●"; col="$(fg "$TX")" ;;
      fail) icon="$(fg "$GOLD")✗"; col="$(fg "$GOLD")" ;;
    esac
    at "$r" 5; printf '%s %s%s  %s%s\e[K' "$icon" "$(fg "$RED")" "${SKANJI[i]}" "$col" "${STITLE[i]}$R$(bgc "$BG")"
    [[ "$st" == ok ]] && { at "$r" $((COLS - 8)); printf '%s済' "$(fg "$GOLD")"; }
    # the rail between seals
    ((i < ${#STEPS[@]} - 1)) && { at $((r + 1)) 5; printf '%s│' "$(fg "$( [[ $st == ok ]] && echo "$RED" || echo "$DI")")"; }
  done
  ((a >= 0)) || return 0
  # progress: a brush stroke along the bottom, red as it fills
  local done=0 w=$((COLS - 20)) fill
  for st in "${SSTATE[@]}"; do [[ "$st" == ok || "$st" == fail ]] && done=$((done + 1)); done
  fill=$(((done * w + (f % 10) * w / (10 * ${#STEPS[@]})) / ${#STEPS[@]}))
  at $((ROWS - 2)) 5
  printf '%s%s%s%s %3d %%' "$(fg "$RED")" "$(rep ━ "$fill")" "$(fg "$DI")" \
    "$(rep ─ $((w - fill)))" $((done * 100 / ${#STEPS[@]}))
}
tail_lines() {      # the last two lines of the step's output, dim, under the timeline
  local r=$((6 + ${#STEPS[@]} * 2 + 1)) l
  mapfile -t l < <(tail -n 2 "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r/\n/g' | tail -n 2)
  at "$r" 9; printf '%s%.*s\e[K' "$(fg "$DI")" $((COLS - 14)) "${l[0]:-}"
  at $((r + 1)) 9; printf '%s%.*s\e[K' "$(fg "$DI")" $((COLS - 14)) "${l[1]:-}"
}
install_all() {
  header "結" "Instalando"
  local i f=0 out pid failed=0
  for ((i = 0; i < ${#STEPS[@]}; i++)); do
    SSTATE[i]=run; out="$(mktemp)"
    { echo "── ${STEPS[i]} ──"; } >>"$LOG"
    run_step "${STEPS[i]}" >"$out" 2>&1 & pid=$!
    while kill -0 "$pid" 2>/dev/null; do draw_timeline "$i" "$f"; tail_lines "$out"; f=$((f + 1)); sleep 0.08; done
    if wait "$pid"; then SSTATE[i]=ok; else SSTATE[i]=fail; failed=$((failed + 1)); fi
    cat "$out" >>"$LOG"; rm -f "$out"
    draw_timeline "$i" "$f"
  done
  tail_lines /dev/null
  FAILED=$failed
}

# ── 6 · the end: sakura petals over ようこそ ─────────────────────────────────────────────────────────────────────
finale() {
  paint_bg "$BG"
  local mid=$((ROWS / 2 - 4))
  bgc "$BG"; fg "$RED"; center $((mid - 1)) "╭$(rep ─ 13)╮"; center $((mid + 1)) "╰$(rep ─ 13)╯"
  at "$mid" $(((COLS - 15) / 2 + 1)); printf '│ %s%sよ う こ そ%s%s │' "$(fg "$TX")" "$B" "$R$(bgc "$BG")" "$(fg "$RED")"
  printf '%s' "$R$(bgc "$BG")"
  if ((FAILED)); then fg "$GOLD"; center $((mid + 2)) "Instalada con $FAILED paso(s) por revisar · registro: ${LOG/#$HOME/\~}"
  else fg "$RED"; center $((mid + 2)) "OcarinaShell está lista"; fi
  fg "$MU"
  center $((mid + 4)) "Cierra la sesión y entra en niri (o reinicia cuando quieras)."
  center $((mid + 6)) "Super+A  lanzador   ·   Super+,  ajustes   ·   Super+?  todos los atajos   ·   Super+D  apps"
  fg "$DI"; center $((mid + 8)) "Si algo se tuerce: docs/05-RESCATE.md   ·   ocarina doctor"
  center $((ROWS - 2)) "Intro para terminar"
  # petals: x, y (half rows), drift
  local n=$((COLS / 6)) px=() py=() pd=() i k=0 x y glyph
  for ((i = 0; i < n; i++)); do px+=($((RANDOM % COLS + 1))); py+=($((-(RANDOM % (ROWS * 2))))); pd+=($((RANDOM % 3 - 1))); done
  while true; do
    for ((i = 0; i < n; i++)); do
      x=${px[i]}; y=$((py[i] / 2))
      # erase where it was (never over the text rows)
      if ((y >= 1 && y <= ROWS && (y < mid - 1 || y > mid + 9) && y != ROWS - 2)); then at "$y" "$x"; printf '%s ' "$(bgc "$BG")"; fi
      py[i]=$((py[i] + 1)); ((k % 3 == 0)) && px[i]=$(((px[i] + pd[i] + COLS - 1) % COLS + 1))
      ((py[i] / 2 > ROWS)) && { py[i]=0; px[i]=$((RANDOM % COLS + 1)); }
      x=${px[i]}; y=$((py[i] / 2))
      if ((y >= 1 && y <= ROWS && (y < mid - 1 || y > mid + 9) && y != ROWS - 2)); then
        glyph="$( ((i % 3)) && echo "❀" || echo "✿")"
        at "$y" "$x"; printf '%s%s' "$(fg "$( ((i % 2)) && echo "$SAKURA" || echo "255;183;197")")" "$glyph"
      fi
    done
    k=$((k + 1))
    ((YES)) && ((k > 60)) && return
    key 0.06 && return
  done
}

# ── the plain run (no terminal, NO_MOTION, --simple) ────────────────────────────────────────────────────────────
plain() {
  echo "OcarinaShell · オカリナシェル — instalador$( ((DEMO)) && echo " (demo: no se cambia nada)")"
  load_groups; load_themes; THEME="${THEME:-kurenai}"; plan
  if needs_sudo && ((!DEMO)); then sudo -v || exit 1; fi
  local i failed=0
  for ((i = 0; i < ${#STEPS[@]}; i++)); do
    printf '  %s %s… ' "${SKANJI[i]}" "${STITLE[i]}"
    if { echo "── ${STEPS[i]} ──"; run_step "${STEPS[i]}"; } >>"$LOG" 2>&1; then echo "✓"
    else echo "✗ (mira $LOG)"; failed=$((failed + 1)); fi
  done
  if ((failed)); then echo "$failed paso(s) por revisar: $LOG"; else echo "Listo. Cierra la sesión y entra en niri."; fi
  exit "$failed"
}

# ── main ────────────────────────────────────────────────────────────────────────────────────────────────────────
[[ -f "$PKGS" ]] || { echo "falta $PKGS: ¿estás dentro del repo de OcarinaShell?" >&2; exit 1; }
((EUID)) || { echo "No lo ejecutes como root: pedirá sudo solo para lo que lo necesite." >&2; exit 1; }
((PLAIN)) && plain

size
printf '\e[?1049h\e[?25l'
stty -echo 2>/dev/null
trap 'size' WINCH
opening
checks
pick_theme
pick_groups
plan
if needs_sudo && ((!DEMO)); then
  # sudo asks once, in the normal screen, and stays warm in the background while the steps run
  printf '\e[?1049l\e[?25h'; stty echo
  echo; echo "  OcarinaShell necesita sudo para: snapshot, paquetes y ficheros de sistema."
  sudo -v || exit 1
  ( while sleep 50; do sudo -n -v || exit; done ) & KEEP_SUDO=$!
  stty -echo; printf '\e[?1049h\e[?25l'
fi
install_all
finale
exit "$FAILED"
