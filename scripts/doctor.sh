#!/usr/bin/env bash
# shellcheck disable=SC2015  # ok/wa/ko always return 0, so `test && ok … || ko …` is a safe if/else
# OcarinaShell · doctor: read-only health check of the system the shell relies on.
# usage: scripts/doctor.sh [--quiet]     (exit 1 if any ✗; ⚠ are warnings)
# Grows phase by phase; `ocarina doctor` will wrap it (and --post-update = smoke tests, docs/06 capa 5).
set -uo pipefail   # no -e on purpose: every check must run even if an earlier one fails

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
quiet=0; [[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]] && quiet=1
export LC_ALL=C
bad=0; warn=0
ok()   { ((quiet)) || printf '  \e[32m✓\e[0m %s\n' "$*"; return 0; }
wa()   { printf '  \e[33m⚠\e[0m %s\n' "$*"; warn=$((warn + 1)); }
ko()   { printf '  \e[31m✗\e[0m %s\n' "$*"; bad=$((bad + 1)); }
sect() { ((quiet)) || printf '\n\e[1m%s\e[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
ver()  { pacman -Q "$1" 2>/dev/null | awk '{print $2}'; }

sect "Versiones"
for p in niri quickshell qt6-base ghostty neovim fish mesa limine plymouth freerdp; do
  v=$(ver "$p"); if [[ -n "$v" ]]; then ok "$p $v"; else wa "$p no instalado"; fi
done
ok "kernel $(uname -r)"

sect "Paquetes críticos desde repos oficiales (06-ACTUALIZACIONES, capa 2)"
foreign=$(pacman -Qqm 2>/dev/null)
for p in niri quickshell ghostty neovim qt6-base qt6-declarative mesa linux-cachyos linux-cachyos-lts paru; do
  if ! pacman -Q "$p" >/dev/null 2>&1; then
    [[ "$p" == ghostty || "$p" == neovim ]] && wa "$p no instalado" || ko "$p no instalado"
  elif grep -qx "$p" <<<"$foreign"; then ko "$p viene del AUR o de fuera de los repos"
  else ok "$p (repo oficial)"; fi
done
if pacman -Qq 2>/dev/null | grep -E '^(niri|quickshell|qt6-[a-z]+)-git$' >/dev/null; then ko "hay paquetes -git del núcleo"; fi
pacman -Q yay >/dev/null 2>&1 && wa "yay instalado (el proyecto usa solo paru, D-005)"
have paru && paru --version >/dev/null 2>&1 && ok "paru funciona" || ko "paru no funciona"

sect "Redes de seguridad"
if snapper list-configs 2>/dev/null | grep -q '^root'; then ok "snapper: config root"; else ko "snapper sin config root"; fi
pacman -Q snap-pac >/dev/null 2>&1 && ok "snap-pac" || ko "falta snap-pac"
systemctl is-enabled --quiet limine-snapper-sync.service 2>/dev/null && ok "limine-snapper-sync activo" \
  || wa "limine-snapper-sync no está habilitado"
pacman -Q kernel-modules-hook >/dev/null 2>&1 && ok "kernel-modules-hook" || wa "falta kernel-modules-hook"
systemctl is-enabled --quiet paccache.timer 2>/dev/null && ok "paccache.timer" || wa "paccache.timer desactivado"
have swaylock && ok "swaylock (bloqueo de emergencia)" || ko "falta swaylock"
if [[ -r /boot/limine.conf ]]; then
  grep -q 'kernel-id=linux-cachyos-lts' /boot/limine.conf && ok "entrada LTS en Limine" || ko "sin entrada LTS en Limine"
else
  wa "no puedo leer /boot/limine.conf sin root (entrada LTS sin comprobar)"
fi
if [[ -e /etc/sudoers.d/90-ocarinashell-temporal ]]; then wa "sudo sin contraseña para todo (/etc/sudoers.d/90-ocarinashell-temporal): quítalo con sudo rm, Mamori solo necesita 91-ocarina-maint"; fi

sect "Sesión"
if [[ -n "${NIRI_SOCKET:-}" ]] && have niri; then
  out=$(niri validate 2>&1) && ok "niri validate" || ko "niri validate: $(tail -n2 <<<"$out")"
else
  wa "no estoy dentro de niri (NIRI_SOCKET vacío)"
fi
if systemctl --user is-active --quiet graphical-session.target; then ok "graphical-session.target activo"
else wa "graphical-session.target inactivo: la sesión no se lanzó con niri-session (los servicios ocarina* no arrancarán)"; fi
for d in waybar mako dunst swaync fuzzel polkit-gnome-authentication-agent-1 polkit-kde-authentication-agent-1 lxpolkit; do
  pgrep -u "$UID" -f "(^|/)$d( |$)" >/dev/null && wa "proceso en conflicto con OcarinaShell: $d"
done
if [[ -f "$HOME/.config/niri/config.kdl" ]] && grep -Eq '^\s*spawn-at-startup\s+"(waybar|mako|dunst|swaync|fuzzel)"' "$HOME/.config/niri/config.kdl"; then
  wa "la config de niri lanza demonios de UI ajenos (spawn-at-startup)"
fi
sect "Shell"
if systemctl --user is-active --quiet ocarinashell 2>/dev/null; then
  ok "ocarinashell.service activo"
  st=$(LC_ALL=C.UTF-8 timeout 2 qs -c ocarina ipc call shell status 2>/dev/null | tail -n1)
  if [[ "$st" == \{* ]]; then
    ok "IPC responde (versión $(jq -r .version <<<"$st"))"
    fails=$(jq -r '.failures | to_entries[] | "\(.key): \(.value)"' <<<"$st" 2>/dev/null)
    if [[ -n "$fails" ]]; then while IFS= read -r f; do ko "módulo no disponible · $f"; done <<<"$fails"
    else ok "todos los módulos cargados"; fi
  else
    ko "la shell no responde por IPC"
  fi
  mem=$(systemctl --user show -p MemoryCurrent --value ocarinashell 2>/dev/null)
  [[ "$mem" =~ ^[0-9]+$ ]] && { mb=$((mem / 1048576)); ((mb < 260)) && ok "memoria ${mb} MB (cgroup)" || wa "memoria ${mb} MB (cgroup, presupuesto 220)"; }
elif systemctl --user is-active --quiet ocarinashell-safe 2>/dev/null; then
  ko "MODO SEGURO activo: la shell normal falla (journalctl --user -u ocarinashell -b)"
else
  wa "ocarinashell.service inactivo"
fi
if out=$(bash "$repo/tests/qml-check.sh" 2>&1); then ok "${out##*$'\n'}"; else ko "QML que no compila: $(grep '✗' <<<"$out" | head -n2 | tr '\n' ' ')"; fi
if out=$(python3 "$repo/tests/contraste.py" 2>&1); then ok "contraste AA en los $(grep -c 'AA ✓' <<<"$out") temas"; else ko "contraste: $(grep -B1 '✗' <<<"$out" | head -n2 | tr '\n' ' ')"; fi
n=$(python3 "$repo/bin/ocarina-binds" list --json 2>/dev/null | jq '[.[] | select(.changed)] | length' 2>/dev/null)
[[ "$n" =~ ^[0-9]+$ ]] && ok "atajos: $n cambiados por ti (Ajustes › Atajos)" || wa "ocarina-binds no responde"
if pgrep -x ddcutil >/dev/null; then wa "hay procesos ddcutil en marcha (en reposo debería haber 0)"; fi
if [[ -r "${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/brightness.json" ]]; then
  ok "brillo: $(jq -r '[.outputs[] | "\(.name)=\(.kind)"] | join(", ")' "${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/brightness.json")"
fi
if grep -q "^i2c_dev " /proc/modules; then ok "i2c-dev cargado (DDC/CI)"; else wa "i2c-dev no cargado: sin brillo DDC/CI en monitores externos"; fi

sect "Energía y juegos (忍 Shinobi · 鬼 Oni)"
helper=/usr/local/libexec/ocarina-powerctl
if [[ -x "$helper" ]]; then
  pst=$("$helper" status 2>/dev/null)
  if jq -e . >/dev/null 2>&1 <<<"$pst"; then
    ok "ayudante de energía (turbo $(jq -r .boost <<<"$pst"), EPP $(jq -r .epp <<<"$pst"), GPU $(jq -r .gpu <<<"$pst"))"
    [[ "$(jq -r .scxAvailable <<<"$pst")" == true ]] && ok "scx_lavd disponible (Oni lo arranca en modo juego)" || wa "sin scx_lavd (scx-scheds): Oni no usará el planificador"
    [[ "$(jq -r .fan.control <<<"$pst")" == true ]] && ok "control del ventilador (thinkpad_acpi fan_control=1)" \
      || wa "sin control del ventilador: «Ventilador al máximo» de Oni necesita sudo bash scripts/root/fase-11.sh y reiniciar"
  else
    ko "ocarina-powerctl status no devuelve JSON (¿versión vieja? sudo bash scripts/install-system.sh)"
  fi
else
  wa "falta el ayudante de energía: sudo bash scripts/install-system.sh"
fi
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell"
for m in shinobi oni; do
  if [[ -r "$state_dir/$m-prev.json" ]] && [[ "$(jq -r .active "$state_dir/$m-prev.json" 2>/dev/null)" == true ]]; then
    wa "$m activo desde $(jq -r .at "$state_dir/$m-prev.json") (si no lo esperas: ocarina $m off)"
  fi
done
for b in steam gamescope mangohud gamemoderun umu-run; do have "$b" && ok "$b" || wa "falta $b (pila de juego, fase 11)"; done
[[ -L "$HOME/.config/gamemode.ini" ]] && grep -q "ocarina\" oni auto-on" "$HOME/.config/gamemode.ini" 2>/dev/null \
  && ok "GameMode avisa a Oni (gamemode.ini)" || wa "gamemode.ini (~/.config) no es el de OcarinaShell: Oni no se activará con los juegos"
id -nG | tr ' ' '\n' | grep -qx gamemode && ok "usuario en el grupo gamemode" || wa "no estás en el grupo gamemode (vuelve a entrar en la sesión tras la fase 11)"
[[ -e /dev/ntsync ]] && ok "ntsync disponible (Wine/Proton más rápidos)" || wa "sin /dev/ntsync"
[[ -r "$HOME/.config/MangoHud/MangoHud.conf" ]] && ok "MangoHud con el tema" || wa "sin ~/.config/MangoHud/MangoHud.conf (ocarina-theme apply)"

sect "滑 Nameraka (vídeo fluido)"
nk="$HOME/.local/libexec/ocarinashell/nameraka"
if [[ -x "$nk" ]]; then
  nkj=$(timeout 10 "$nk" self-test --json 2>/dev/null | tail -n1)
  if [[ "$(jq -r .available <<<"$nkj" 2>/dev/null)" == true ]]; then
    ok "self-test: captura de niri, capa overlay, Vulkan DMA-BUF, lsfg-vk y la DLL de Lossless Scaling"
  else
    wa "Fluido no disponible: $(jq -r .reason <<<"$nkj" 2>/dev/null || echo "self-test sin respuesta") (código $(jq -r .code <<<"$nkj" 2>/dev/null))"
  fi
  systemctl --user is-enabled -q ocarina-nameraka.socket 2>/dev/null && ok "socket activado (0 procesos hasta que lo enciendes)" \
    || wa "ocarina-nameraka.socket sin habilitar: bash scripts/install.sh"
  cal="${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/nameraka/calibration.json"
  if [[ -r "$cal" ]]; then
    [[ "$(jq -r .dll "$cal")" == "$(jq -r .dllSha256 <<<"$nkj" 2>/dev/null)" ]] && ok "calibrado con la DLL actual" \
      || wa "Steam actualizó la DLL desde la calibración: Ajustes › 滑 Vídeo fluido › Calibrar"
  else
    wa "sin calibrar (usa valores medidos en la 860M): ocarina nameraka calibrate"
  fi
  if pgrep -x nameraka >/dev/null && ! systemctl --user is-active -q ocarina-nameraka.service; then
    wa "hay un proceso nameraka fuera del servicio (¿una prueba a mano?)"
  fi
else
  wa "Nameraka sin compilar: bash scripts/install.sh (necesita meson, ninja, vulkan-headers, wayland-protocols, wlr-protocols)"
fi

sect "船 Fune (apps de Windows)"
fune="$HOME/.local/bin/ocarina-fune"
if [[ -x "$fune" ]] && have podman; then
  # read-only smoke test (never starts the VM): «ok/aviso/FALLO <texto>» per line
  while IFS= read -r line; do
    case "$line" in
      "ok    "*) ok "${line#ok    }" ;;
      "aviso "*) wa "${line#aviso }" ;;
      "FALLO "*) ko "${line#FALLO }" ;;
    esac
  done < <(timeout 30 "$fune" smoke 2>/dev/null || true)
  if pgrep -u "$USER" -f "podman events .*WinApps" >/dev/null && [[ "$(timeout 10 "$fune" status --json 2>/dev/null | jq -r .state)" == exited ]]; then
    wa "podman events sigue vivo con Windows apagada (debería ser 0 procesos)"
  fi
else
  ok "Fune sin instalar (opcional: docs/WINDOWS.md)"
fi

sect "蛇 Snake (IA local) · 守 Mamori"
if out=$(timeout 20 python3 "$repo/bin/ocarina-snake" smoke 2>&1); then ok "Snake: tareas, esquemas y acciones (smoke)"; else ko "Snake smoke: $(tail -n2 <<<"$out" | tr '\n' ' ')"; fi
ok "Snake: $(timeout 10 python3 "$repo/bin/ocarina-snake" status 2>/dev/null | head -n1)"
if have whisper-cli; then
  [[ -s "$(python3 "$repo/bin/ocarina-snake" models path whisper 2>/dev/null)" ]] && ok "声 voz: whisper-cli y el modelo large-v3-turbo" \
    || wa "声 voz sin modelo: ocarina-snake models pull whisper"
else
  wa "声 voz sin whisper-cpp (pacman -S whisper-cpp)"
fi
if [[ -x "$repo/bin/ocarina-mamori" ]]; then
  st=$(timeout 15 python3 "$repo/bin/ocarina-mamori" status 2>/dev/null | head -n3 | tr '\n' ' ')
  [[ -n "$st" ]] && ok "${st//  / }" || ko "ocarina-mamori status no responde"
  systemctl --user is-enabled --quiet ocarina-mamori.timer 2>/dev/null && ok "temporizador de Mamori activo" || wa "ocarina-mamori.timer desactivado"
fi

sect "Fuentes"
for f in "JetBrainsMono Nerd Font" "Noto Sans CJK JP" "Geist" "Zen Kaku Gothic New" "Shippori Mincho B1" "Yuji Syuku" "Unbounded" "Material Symbols Rounded"; do
  fc-list ":family=$f" family 2>/dev/null | grep -q . && ok "$f" || ko "falta la fuente $f"
done
jp=$(fc-match -f '%{family[0]}' 'sans-serif:lang=ja' 2>/dev/null)
[[ "$jp" == *JP* || "$jp" == "Zen Kaku Gothic New" ]] && ok "sans-serif:lang=ja → $jp" || wa "sans-serif:lang=ja → $jp (¿formas chinas?)"

sect "Tema"
if [[ -r "${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/theme.json" ]]; then
  ok "tema activo: $(python3 "$repo/bin/ocarina-theme" current 2>/dev/null)"
  out=$(python3 "$repo/bin/ocarina-theme" apply "$(python3 "$repo/bin/ocarina-theme" current 2>/dev/null | cut -d' ' -f1)" --dry-run 2>&1) \
    && ok "plantillas renderizan y validan (dry-run)" || ko "ocarina-theme --dry-run: $(tail -n3 <<<"$out")"
else
  wa "ningún tema aplicado (ocarina-theme apply kurenai)"
fi

sect "Terminal"
if have ghostty; then
  out=$(ghostty +validate-config 2>&1) && ok "Ghostty $(ver ghostty): config válida" || ko "config de Ghostty: $(head -n2 <<<"$out")"
  fx="${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/theme/ghostty-effects.conf"
  [[ -r "$fx" ]] && ok "efectos de terminal: $(python3 "$repo/bin/ocarina-theme" effects status 2>/dev/null)" || wa "sin ghostty-effects.conf (lo escribe la shell)"
fi
if have fish; then
  ms=$( { TIMEFORMAT=%R; time fish -i -c exit >/dev/null 2>&1; } 2>&1 | awk '{printf "%d", $1 * 1000}')
  ((ms < 60)) && ok "fish -i arranca en ${ms} ms" || wa "fish -i tarda ${ms} ms (presupuesto 40)"
  grep -qF "OcarinaShell · greeting" "$HOME/.config/fish/config.fish" 2>/dev/null && ok "saludo de fish enganchado" \
    || wa "falta el bloque del saludo en config.fish: bash scripts/install.sh"
fi
have starship && [[ -r "$HOME/.config/starship.toml" ]] && ok "starship $(ver starship) con el prompt de OcarinaShell" || wa "starship sin configurar"
hb="${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/niri/honban-rules.kdl"
if [[ -r "$hb" ]]; then
  n=$(grep -c 'window-rule' "$hb"); ok "本番 Honban: regla generada ($( ((n)) && echo "con hosts de producción" || echo "sin hosts de producción"))"
fi

sect "Neovim"
if have nvim; then
  if out=$(python3 "$repo/bin/ocarina-nvim-health" 2>&1); then
    ok "Neovim $(nvim --version | head -n1 | cut -d' ' -f2): $(grep -o 'arranque: [0-9.]* ms' <<<"$out"), checkhealth sin errores, LSP de Lua y QML"
  else
    ko "Neovim: $(grep '✗' <<<"$out" | tail -n +2 | head -n2 | tr '\n' ' ')"
  fi
  [[ -r "${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/theme/effects.json" ]] || wa "sin theme/effects.json (lo escribe la shell)"
fi

sect "Enlaces del repo"
pending=$(bash "$repo/scripts/install.sh" --dry-run 2>&1 | grep -c '\[dry-run\] ln')
((pending == 0)) && ok "scripts/install.sh al día" || wa "$pending enlaces pendientes: bash scripts/install.sh"

printf '\n'
if ((bad)); then printf '\e[31m%d problema(s)\e[0m, %d aviso(s)\n' "$bad" "$warn"; exit 1; fi
printf '\e[32mSin problemas\e[0m, %d aviso(s)\n' "$warn"
