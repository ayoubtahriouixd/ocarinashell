#!/usr/bin/env bash
# OcarinaShell · fase 09 · run as: sudo bash scripts/root/fase-09.sh
# Idempotent. Steps:
#   1. snapper snapshot
#   2. full system upgrade (pacman -Syu) together with the Neovim toolchain: never partial upgrades
#      (docs/06-ACTUALIZACIONES, capa 2). Every LSP server / formatter comes from the official repos (not mason),
#      so pacman — and later 守 Mamori — keeps them updated with the rest of the system (D-054).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecútalo con: sudo bash $0" >&2
  exit 1
fi

say() { printf '\n\e[1;31m▌\e[0m \e[1m%s\e[0m\n' "$*"; }

pkgs=(
  lua-language-server pyright typescript-language-server bash-language-server vscode-json-languageserver
  yaml-language-server marksman taplo-cli          # LSP (qmlls viene con qt6-declarative)
  ruff shfmt prettier                               # formateadores (stylua y qmlformat ya están)
  tree-sitter-cli                                   # nvim-treesitter (rama main) compila los parsers con él
  chafa                                             # respaldo del logo del dashboard fuera de Ghostty
)

say "1/2 Snapshot de snapper"
snapper -c root create -d "ocarinashell: fase 09, antes de actualizar e instalar el kit de Neovim" --print-number

say "2/2 Actualización completa + kit de Neovim (pacman -Syu)"
pacman -Syu --needed --noconfirm "${pkgs[@]}"

echo -e "\nListo. No hace falta reiniciar; vuelve a Claude Code y dile «hecho»."
