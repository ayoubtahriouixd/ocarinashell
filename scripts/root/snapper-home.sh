#!/usr/bin/env bash
# OcarinaShell · 控 Hikae ligero: snapshots de snapper para @home (D-070; sustituye a restic por decisión de Ayoub).
# usage: sudo bash scripts/root/snapper-home.sh [instalar|estado|quitar]
#
# Btrfs CoW: un snapshot no copia datos, solo retiene los bloques que cambian después. Subvolúmenes anidados (el disco
# de Windows de Fune) quedan fuera solos. Retención: 24 horarios + 7 diarios + 4 semanales; snapper borra los más
# viejos si el disco baja del 20 % libre o los snapshots pasan del 30 % del sistema de ficheros.
# El usuario que lanza sudo queda en ALLOW_USERS + SYNC_ACL: puede listar y leer sus snapshots sin root
# (`ocarina backup list|restore`). snap-pac sigue haciendo pre/post solo de root (su valor por defecto).
# «quitar» deja la config sin timeline (no borra ningún snapshot: eso lo decide Ayoub con snapper delete).
set -euo pipefail
export LC_ALL=C

cmd="${1:-instalar}"
[[ $EUID -eq 0 ]] || { echo "Ejecútalo con: sudo bash $0 $*" >&2; exit 1; }
user="${SUDO_USER:-}"
[[ -n "$user" && "$user" != root ]] || { echo "lánzalo con sudo desde tu usuario (necesito SUDO_USER)" >&2; exit 1; }
command -v snapper >/dev/null || { echo "falta snapper" >&2; exit 1; }

has_config() { snapper --csvout list-configs 2>/dev/null | cut -d, -f1 | grep -qx home; }

case "$cmd" in
  estado)
    if has_config; then
      snapper -c home get-config | grep -E 'ALLOW_USERS|SYNC_ACL|TIMELINE_(CREATE|LIMIT_HOURLY|LIMIT_DAILY|LIMIT_WEEKLY)|SPACE_LIMIT|FREE_LIMIT'
      snapper -c home list | tail -n 5
    else
      echo "sin config «home»"
    fi
    systemctl is-enabled snapper-timeline.timer snapper-cleanup.timer || true
    ;;
  instalar)
    [[ "$(findmnt -no FSTYPE /home)" == btrfs ]] || { echo "/home no es btrfs" >&2; exit 1; }
    btrfs subvolume show /home >/dev/null 2>&1 || { echo "/home no es un subvolumen" >&2; exit 1; }
    snapper -c root create -d "ocarinashell: fase 14, antes de snapper para home" >/dev/null
    if ! has_config; then
      echo "· creando la config «home» (subvolumen /home/.snapshots)"
      snapper -c home create-config /home
    fi
    snapper -c home set-config \
      ALLOW_USERS="$user" SYNC_ACL=yes \
      TIMELINE_CREATE=yes TIMELINE_CLEANUP=yes TIMELINE_MIN_AGE=1800 \
      TIMELINE_LIMIT_HOURLY=24 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=4 \
      TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_QUARTERLY=0 TIMELINE_LIMIT_YEARLY=0 \
      NUMBER_CLEANUP=yes NUMBER_LIMIT=20 NUMBER_LIMIT_IMPORTANT=10 \
      SPACE_LIMIT=0.3 FREE_LIMIT=0.2 BACKGROUND_COMPARISON=no
    systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
    snapper -c home create -c number -d "ocarinashell: primera foto de home"
    echo "· listo:"; "$0" estado
    ;;
  quitar)
    has_config || { echo "sin config «home»: nada que hacer"; exit 0; }
    snapper -c home set-config TIMELINE_CREATE=no
    echo "· timeline de home apagado (los snapshots existentes siguen ahí: snapper -c home list)"
    ;;
  *) echo "uso: sudo bash $0 [instalar|estado|quitar]" >&2; exit 1 ;;
esac
