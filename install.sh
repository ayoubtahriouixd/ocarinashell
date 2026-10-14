#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
#  OcarinaShell · オカリナシェル — instalador del kit
#  https://github.com/ayoubtahriouixd/ocarinashell
#
#    curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash
#    curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash -s -- --help
#
#  Qué hace: comprueba tu equipo, deja el kit en ~/ocarinashell (repo git en la última versión publicada) y verifica
#  su red de seguridad. Qué NO hace: instalar paquetes, tocar /etc o /boot ni cambiar tu escritorio. Eso lo hace
#  Claude Code en las fases, con snapshot previo. Únicas excepciones, siempre preguntando: instalar git si falta y,
#  solo si lo pides, el sudo temporal de la construcción (--sudo-temporal).
#  No confundir con scripts/install.sh, que crea la fase 0 para enlazar el repo con tu sistema.
# ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="${OCARINA_REPO:-ayoubtahriouixd/ocarinashell}"
GIT_URL="${OCARINA_GIT_URL:-https://github.com/${REPO}.git}"
DEST="${OCARINA_DIR:-$HOME/ocarinashell}"
WANT="${OCARINA_VERSION:-latest}"
SUDO_FILE=/etc/sudoers.d/90-ocarinashell-temporal
MODE=install          # install | update | check
SUDO_TEMP=ask         # ask | yes | no
ASSUME_YES=0
FORCE=0
WARNINGS=0
TAG=""
WORK=""
ALREADY=0

usage() {
	cat <<EOF
OcarinaShell · instalador del kit

Uso:  bash install.sh [opciones]
      curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- [opciones]

Opciones:
  --version <vX.Y.Z>  instala esa versión (por defecto, la última publicada)
  --update            actualiza un kit ya instalado sin tocar tu trabajo (fusiona la nueva versión)
  --check             solo comprueba el equipo; no descarga ni cambia nada
  --sudo-temporal     activa sudo sin contraseña SOLO durante la construcción (lo quita la fase 17)
  --no-sudo-temporal  no lo preguntes
  --dir <ruta>        otra carpeta (solo para pruebas: el kit espera ~/ocarinashell)
  --force             continúa aunque el sistema no sea CachyOS/Arch
  -y, --yes           sin preguntas (respuestas por defecto; nunca activa el sudo temporal por sí solo)
  -h, --help          esta ayuda

Variables: OCARINA_REPO (usuario/repo), OCARINA_VERSION, OCARINA_DIR, NO_COLOR.
EOF
}

# ─── interfaz ─────────────────────────────────────────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	RED=$'\e[38;5;197m' GRN=$'\e[38;5;114m' YLW=$'\e[38;5;179m' DIM=$'\e[2m' BLD=$'\e[1m' RST=$'\e[0m'
else
	RED="" GRN="" YLW="" DIM="" BLD="" RST=""
fi
ok()   { printf '  %s✓%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '  %s!%s %s\n' "$YLW" "$RST" "$*"; WARNINGS=$((WARNINGS + 1)); }
bad()  { printf '  %s✗%s %s\n' "$RED" "$RST" "$*"; }
info() { printf '    %s%s%s\n' "$DIM" "$*" "$RST"; }
step() { printf '\n%s%s%s\n' "$BLD" "$*" "$RST"; }
die()  { printf '\n%s✗ %s%s\n' "$RED" "$*" "$RST" >&2; exit 1; }

have_tty() { (exec </dev/tty) 2>/dev/null; }

# ask "pregunta" s|n → 0 = sí. Lee de /dev/tty (con «curl | bash», stdin es el propio script).
ask() {
	local def="$2" ans="" hint="s/N"
	[[ $def == s ]] && hint="S/n"
	if [[ $ASSUME_YES == 1 ]] || ! have_tty; then
		[[ $def == s ]]
		return
	fi
	printf '  %s?%s %s [%s] ' "$RED" "$RST" "$1" "$hint" >/dev/tty
	read -r ans </dev/tty || ans=""
	ans="${ans:-$def}"
	[[ ${ans,,} == s* || ${ans,,} == y* ]]
}

banner() {
	printf '\n  %sOcarina%sShell%s  %sオカリナシェル%s\n' "$BLD" "$RED" "$RST" "$DIM" "$RST"
	printf '  %sinstalador del kit · %s%s\n' "$DIM" "$REPO" "$RST"
}

# ─── comprobaciones ───────────────────────────────────────────────────────────────────────────────────────────
# shellcheck disable=SC1091  # /etc/os-release is sourced in a subshell on purpose
os_field() { (. /etc/os-release 2>/dev/null && printf '%s' "${!1:-}") || true; }

need_pkg() {   # need_pkg <orden> <paquete> <obligatorio 1|0> <para qué>
	local cmd="$1" pkg="$2" required="$3" why="$4"
	if command -v "$cmd" >/dev/null 2>&1; then
		ok "$cmd"
		return 0
	fi
	if [[ $required == 1 ]]; then bad "falta $cmd ($why)"; else warn "falta $cmd ($why)"; fi
	if [[ $MODE == check ]]; then
		info "instálalo con: sudo pacman -S --needed $pkg"
		return 0
	fi
	if command -v pacman >/dev/null 2>&1 && ask "¿Instalar $pkg con pacman ahora?" s; then
		sudo pacman -S --needed --noconfirm "$pkg" && ok "$pkg instalado" && return 0
	fi
	[[ $required == 1 ]] && die "Instala $pkg (sudo pacman -S --needed $pkg) y vuelve a ejecutar el instalador."
	return 0
}

preflight() {
	step "1 · Tu equipo"
	if [[ $EUID -eq 0 && ${OCARINA_ALLOW_ROOT:-0} != 1 ]]; then
		die "No lo ejecutes como root ni con sudo: el kit va en tu carpeta personal."
	fi
	local id like name
	id="$(os_field ID)" like="$(os_field ID_LIKE)" name="$(os_field PRETTY_NAME)"
	name="${name:-$(uname -s)}"
	if [[ $id == cachyos ]]; then
		ok "$name"
	elif [[ $id == arch || $like == *arch* ]]; then
		warn "$name: compatible, pero el kit está afinado para CachyOS (sus repos y kernels)"
	else
		bad "$name: el kit es para CachyOS (o Arch)"
		[[ $FORCE == 1 ]] || die "Usa --force si aun así quieres descargarlo (no se instalará nada en el sistema)."
	fi
	if [[ $(uname -m) == x86_64 ]]; then ok "x86_64"; else warn "$(uname -m): el kit está preparado para x86_64"; fi

	if command -v niri >/dev/null 2>&1; then
		ok "niri $(niri --version 2>/dev/null | awk '{print $2; exit}')"
	else
		warn "niri no está instalado (CachyOS lo ofrece en su instalador; la fase 0 lo comprueba)"
	fi
	if [[ -n ${NIRI_SOCKET:-} || ${XDG_CURRENT_DESKTOP:-} == *niri* ]]; then
		ok "sesión de niri activa"
	else
		info "no estás en una sesión de niri: para instalar da igual; las fases se hacen dentro de niri"
	fi
	if [[ $(findmnt -no FSTYPE / 2>/dev/null || true) == btrfs ]]; then
		ok "/ en Btrfs (snapshots)"
	else
		warn "/ no está en Btrfs: sin snapshots pierdes la primera red de seguridad"
	fi
	if command -v snapper >/dev/null 2>&1; then ok "snapper"; else warn "snapper no está (la fase 0 lo prepara)"; fi
	if [[ -e /boot/limine.conf || -e /boot/limine/limine.conf || -e /efi/limine.conf ]] || command -v limine >/dev/null 2>&1; then
		ok "Limine"
	else
		info "no veo Limine: la fase 13 (arranque) se adaptará a tu cargador o se omitirá"
	fi
	local mem free
	mem="$(awk '/^MemTotal/ {printf "%d", $2 / 1048576 + 0.5}' /proc/meminfo 2>/dev/null || echo 0)"
	free="$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 {printf "%d", $4 / 1048576}' || echo 0)"
	ok "${mem} GB de RAM · ${free} GB libres en tu carpeta personal"
	((free >= 20)) || warn "poco espacio: la base necesita unos 10 GB; Windows (Fune) ~70 GB y la IA local (Snake) ~20 GB si los usas"

	need_pkg git git 1 "descargar el kit y guardar el progreso de cada fase"
	need_pkg python3 python 0 "red de seguridad de Claude Code y herramientas del kit"

	if command -v claude >/dev/null 2>&1; then
		ok "Claude Code $(claude --version 2>/dev/null | awk '{print $1; exit}')"
	else
		warn "Claude Code no está instalado (lo necesitas para construir el escritorio)"
		info "instálalo con:  curl -fsSL https://claude.ai/install.sh | bash"
		info "requiere plan Pro, Max, Team, Enterprise o Console de Anthropic"
	fi
}

# ─── descarga ─────────────────────────────────────────────────────────────────────────────────────────────────
cleanup() { [[ -n $WORK && -d $WORK ]] && rm -rf "$WORK"; return 0; }

latest_tag() {   # última versión estable publicada (vX.Y.Z), o vacío
	git ls-remote --tags --refs "$1" 'v*' 2>/dev/null | awk -F/ '{print $3}' |
		grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true
}

resolve_tag() {
	if [[ $WANT != latest ]]; then
		TAG="$WANT"
		return
	fi
	TAG="$(latest_tag "$GIT_URL")"
	if [[ -z $TAG ]]; then
		TAG=main
		info "no hay versiones publicadas todavía: uso la rama main"
	fi
}

ensure_identity() {   # Claude Code hace un commit por fase: git necesita nombre y correo
	local dir="$1"
	if [[ -z $(git -C "$dir" config user.name || true) ]]; then
		git -C "$dir" config user.name "$(id -un)"
		info "git: nombre «$(id -un)» para los commits de las fases (cámbialo con git config user.name)"
	fi
	if [[ -z $(git -C "$dir" config user.email || true) ]]; then
		git -C "$dir" config user.email "$(id -un)@$(uname -n).local"
	fi
}

install_kit() {
	step "2 · Descarga"
	resolve_tag
	if [[ -e $DEST ]]; then
		if [[ -d $DEST/.git ]] && git -C "$DEST" config --get remote.upstream.url >/dev/null 2>&1; then
			ok "el kit ya está instalado en $DEST ($(git -C "$DEST" describe --tags --always 2>/dev/null))"
			info "para actualizarlo:  bash $DEST/install.sh --update"
			ALREADY=1
			return 0
		fi
		if [[ -z $(ls -A "$DEST" 2>/dev/null) ]]; then
			rmdir "$DEST"
		else
			local bak
			bak="${DEST}.bak-$(date +%Y%m%d-%H%M%S)"
			mv "$DEST" "$bak"
			ok "lo que había en $DEST está a salvo en $bak"
		fi
	fi
	mkdir -p "$(dirname "$DEST")"
	WORK="$(mktemp -d "$(dirname "$DEST")/.ocarinashell-XXXXXX")"
	trap cleanup EXIT
	info "descargando $TAG desde $GIT_URL…"
	if ! git clone --quiet --branch "$TAG" "$GIT_URL" "$WORK/kit" 2>"$WORK/err"; then
		local why
		why="$(sed -n 's/^fatal: //p' "$WORK/err" | head -n 1)"
		die "No se pudo descargar $TAG: ${why:-$(tail -n 1 "$WORK/err")}. ¿Repositorio público y versión correcta?"
	fi
	git -C "$WORK/kit" switch --quiet -C main
	git -C "$WORK/kit" branch --quiet --unset-upstream main 2>/dev/null || true
	git -C "$WORK/kit" remote rename origin upstream
	ensure_identity "$WORK/kit"
	mv "$WORK/kit" "$DEST"
	ok "kit $TAG en $DEST"
	info "tu trabajo irá en la rama local main; las actualizaciones llegan de «upstream»"
}

update_kit() {
	step "2 · Actualización"
	[[ -d $DEST/.git ]] || die "No hay un kit instalado con git en $DEST (instálalo sin --update)."
	local remote=upstream current
	git -C "$DEST" config --get remote.upstream.url >/dev/null 2>&1 || remote=origin
	git -C "$DEST" fetch --quiet --tags "$remote" || die "No se pudo contactar con $remote."
	if [[ $WANT == latest ]]; then
		TAG="$(git -C "$DEST" tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)"
	else
		TAG="$WANT"
	fi
	[[ -n $TAG ]] || die "No hay versiones publicadas en $remote."
	current="$(git -C "$DEST" describe --tags --abbrev=0 2>/dev/null || echo '?')"
	if git -C "$DEST" merge-base --is-ancestor "$TAG" HEAD 2>/dev/null; then
		ok "ya tienes $TAG (o algo más nuevo): nada que hacer"
		return 0
	fi
	if ! git -C "$DEST" diff --quiet || ! git -C "$DEST" diff --cached --quiet; then
		die "Tienes cambios sin guardar en $DEST: haz commit (o pídeselo a Claude Code) y repite."
	fi
	ensure_identity "$DEST"
	if git -C "$DEST" merge --quiet --ff-only "$TAG" >/dev/null 2>&1; then
		ok "actualizado: $current → $TAG"
	elif git -C "$DEST" merge --quiet --no-edit -m "kit: fusiona $TAG" "$TAG" >/dev/null 2>&1; then
		ok "actualizado: $current → $TAG (fusionado con tu trabajo de las fases)"
	else
		git -C "$DEST" merge --abort >/dev/null 2>&1 || true
		die "La versión $TAG choca con cambios tuyos; no se ha tocado nada. Pídele a Claude Code: «fusiona la versión $TAG del kit»."
	fi
	info "novedades: $DEST/CHANGELOG.md"
}

verify_kit() {
	step "3 · Comprobación"
	local f out
	for f in CLAUDE.md README.md .claude/settings.json scripts/hooks/guard.sh scripts/hooks/guard.py docs/fases/fase-00.md; do
		[[ -e $DEST/$f ]] || die "Falta $f: la descarga está incompleta. Vuelve a ejecutar el instalador."
	done
	ok "versión $(git -C "$DEST" describe --tags --always 2>/dev/null) · $(git -C "$DEST" rev-parse --short HEAD)"
	if command -v python3 >/dev/null 2>&1; then
		info "probando la red de seguridad de Claude Code (unos segundos)…"
		if out="$(cd "$DEST" && python3 scripts/hooks/test-guard.py 2>&1)"; then
			ok "hook de guardia: $(tail -n 1 <<<"$out")"
		else
			warn "el hook de guardia no pasó sus pruebas:"
			info "$(tail -n 3 <<<"$out")"
		fi
	fi
}

sudo_temporal() {
	[[ $SUDO_TEMP == no ]] && return 0
	if [[ -e $SUDO_FILE ]]; then
		ok "sudo temporal ya activo ($SUDO_FILE)"
		return 0
	fi
	if [[ $SUDO_TEMP == ask ]]; then
		[[ $ASSUME_YES == 1 ]] && return 0
		have_tty || return 0
		step "4 · Opcional: sudo temporal"
		info "Claude Code instala muchos paquetes en las fases. Con sudo sin contraseña SOLO mientras"
		info "se construye, no se para a pedírtela. Lo quita la fase 17 (o tú: sudo rm $SUDO_FILE)."
		info "Sin él, Claude Code te dará scripts para que los ejecutes tú."
		ask "¿Activarlo ahora?" n || { info "sin sudo temporal"; return 0; }
	fi
	command -v sudo >/dev/null 2>&1 || die "Falta sudo."
	printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" | sudo tee "$SUDO_FILE" >/dev/null
	sudo chmod 440 "$SUDO_FILE"
	if sudo visudo -cf "$SUDO_FILE" >/dev/null 2>&1; then
		ok "sudo temporal activo (lo quita la fase 17)"
	else
		sudo rm -f "$SUDO_FILE"
		bad "visudo rechazó el fichero; deshecho, sudo sigue como estaba"
	fi
}

next_steps() {
	local home_dest="${DEST/#$HOME/\~}"
	printf '\n  Kit de %sOcarina%sShell%s listo en %s %s(%s)%s\n' "$BLD" "$RED" "$RST" "$home_dest" "$DIM" "$TAG" "$RST"
	printf '\n  %sSiguiente:%s\n' "$BLD" "$RST"
	if ! command -v claude >/dev/null 2>&1; then
		printf '    curl -fsSL https://claude.ai/install.sh | bash   %s# Claude Code; luego abre otra terminal%s\n' "$DIM" "$RST"
	fi
	printf '    cd %s\n' "$home_dest"
	printf '    claude --permission-mode acceptEdits            %s# acepta «confiar en esta carpeta»%s\n' "$DIM" "$RST"
	printf '    /fase 0                                         %s# dentro de Claude Code%s\n' "$DIM" "$RST"
	printf '\n  %sGuía: %s/README.md · Rescate: %s/docs/05-RESCATE.md%s\n' "$DIM" "$home_dest" "$home_dest" "$RST"
	((WARNINGS == 0)) || printf '  %sHay %d aviso(s) arriba: revísalos antes de la fase 0.%s\n' "$YLW" "$WARNINGS" "$RST"
	printf '\n'
}

main() {
	while (($#)); do
		case "$1" in
			--version) [[ $# -ge 2 ]] || die "--version necesita un valor (p. ej. v1.0.0)"; WANT="$2"; shift 2 ;;
			--version=*) WANT="${1#*=}"; shift ;;
			--dir) [[ $# -ge 2 ]] || die "--dir necesita una ruta"; DEST="$2"; shift 2 ;;
			--dir=*) DEST="${1#*=}"; shift ;;
			--update) MODE=update; shift ;;
			--check) MODE=check; shift ;;
			--sudo-temporal) SUDO_TEMP=yes; shift ;;
			--no-sudo-temporal) SUDO_TEMP=no; shift ;;
			--force) FORCE=1; shift ;;
			-y | --yes) ASSUME_YES=1; shift ;;
			-h | --help) usage; exit 0 ;;
			*) die "Opción desconocida: $1 (usa --help)" ;;
		esac
	done
	[[ $REPO =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+$ ]] ||
		die "Este instalador no tiene configurado su repositorio (OCARINA_REPO=usuario/repo)."
	DEST="${DEST%/}"

	banner
	[[ $DEST == "$HOME/ocarinashell" ]] || warn "carpeta $DEST: el kit espera ~/ocarinashell (otras rutas, solo para pruebas)"
	preflight
	case "$MODE" in
		check)
			printf '\n'
			if ((WARNINGS == 0)); then ok "todo listo para instalar"; else info "$WARNINGS aviso(s); nada bloquea la instalación"; fi
			return 0
			;;
		update)
			update_kit
			verify_kit
			;;
		install)
			install_kit
			if [[ $ALREADY == 0 ]]; then
				verify_kit
				sudo_temporal
				next_steps
			fi
			;;
	esac
}

main "$@"
