#!/usr/bin/env bash
# Publica el kit en TU GitHub con un solo comando, desde la carpeta del kit:
#
#   bash tools/publicar-github.sh [nombre-del-repo]          # por defecto: ocarinashell
#
# (Si te llegó como ocarinashell.bundle: git clone ocarinashell.bundle ~/ocarinashell-publicar && cd ~/ocarinashell-publicar)
#
# Necesita GitHub CLI con tu sesión iniciada:  sudo pacman -S --needed github-cli && gh auth login
# Hace: escribe tu usuario/repo en el README y el instalador, crea el repo PÚBLICO (el instalador por curl lo
# necesita), sube el código, crea la release vX.Y.Z (versión de CHANGELOG.md) con el zip y SHA256SUMS, y pone la
# descripción y los temas del repo. Si el repo ya existe y tiene contenido, se para sin tocar nada.
set -euo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then RED=$'\e[38;5;197m' GRN=$'\e[38;5;114m' DIM=$'\e[2m' RST=$'\e[0m'; else RED="" GRN="" DIM="" RST=""; fi
ok()  { printf '  %s✓%s %s\n' "$GRN" "$RST" "$*"; }
die() { printf '\n%s✗ %s%s\n' "$RED" "$*" "$RST" >&2; exit 1; }

main() {
	local name="${1:-ocarinashell}" version owner repo
	cd "$(dirname "$0")/.."
	[[ -f CHANGELOG.md && -f install.sh && -f tools/release.py ]] || die "Ejecútalo desde la carpeta del kit."
	command -v gh >/dev/null 2>&1 || die "Falta GitHub CLI: sudo pacman -S --needed github-cli && gh auth login"
	gh auth status >/dev/null 2>&1 || die "Inicia sesión en GitHub CLI: gh auth login"
	command -v git >/dev/null 2>&1 || die "Falta git: sudo pacman -S --needed git"
	version="$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/v\1/p' CHANGELOG.md | head -n 1)"
	[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "CHANGELOG.md no tiene una versión «## [X.Y.Z]»."
	owner="$(gh api user --jq .login)"
	repo="$owner/$name"
	printf '\n  Publicar %s%s%s · %s\n\n' "$RED" "$repo" "$RST" "$version"

	if gh repo view "$repo" >/dev/null 2>&1; then
		[[ $(gh api "repos/$repo" --jq .size) == 0 ]] || die "github.com/$repo ya existe y tiene contenido: no lo toco."
		[[ $(gh api "repos/$repo" --jq .private) == false ]] || die "github.com/$repo es privado: el instalador por curl necesita que sea público."
		ok "repo vacío ya creado: github.com/$repo"
	fi

	python3 tools/release.py "$version" --repo "$repo"
	if [[ ! -d .git ]]; then
		git init -q -b main
	fi
	if git remote get-url origin >/dev/null 2>&1 && [[ $(git remote get-url origin) != *github.com* ]]; then
		git remote remove origin   # p. ej. clonado de un fichero .bundle
	fi
	if [[ -z $(git config user.email || true) ]]; then   # sin identidad de git: la de tu cuenta de GitHub
		git config user.name "$(gh api user --jq '.name // .login')"
		git config user.email "$(gh api user --jq .id)+$owner@users.noreply.github.com"
	fi
	git add -A
	if ! git diff --cached --quiet 2>/dev/null || ! git rev-parse -q --verify HEAD >/dev/null; then
		git -c commit.gpgsign=false commit -q -m "OcarinaShell $version"
	fi
	# todavía no hay nada publicado (lo comprobamos arriba): la etiqueta va siempre al commit que se sube
	git -c tag.gpgsign=false tag -f -a "$version" -m "OcarinaShell $version" >/dev/null
	ok "commit y etiqueta $version"

	if gh repo view "$repo" >/dev/null 2>&1; then
		git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$repo.git"
		git push -q -u origin main
	else
		gh repo create "$repo" --public --source . --remote origin --push \
			--description "Escritorio japonés para CachyOS + niri + Quickshell, construido fase a fase por Claude Code" \
			--homepage "https://github.com/$repo#readme"
	fi
	git push -q origin "$version"
	ok "código subido"

	gh release create "$version" "dist/ocarinashell-kit-$version.zip" dist/SHA256SUMS install.sh \
		--repo "$repo" --title "OcarinaShell $version" --notes-file dist/RELEASE-NOTES.md --latest >/dev/null
	ok "release $version con el zip, SHA256SUMS e install.sh"
	gh repo edit "$repo" --add-topic niri,quickshell,cachyos,wayland,linux-desktop,japanese,claude-code,dotfiles,arch-linux,ricing >/dev/null
	ok "descripción y temas"

	printf '\n  Listo: https://github.com/%s\n' "$repo"
	printf '  Instalar:  curl -fsSL https://raw.githubusercontent.com/%s/main/install.sh | bash\n' "$repo"
	printf '  %sÚltimo toque (solo desde la web): Settings → Social preview → docs/img/social-preview.png%s\n\n' "$DIM" "$RST"
}

main "$@"
