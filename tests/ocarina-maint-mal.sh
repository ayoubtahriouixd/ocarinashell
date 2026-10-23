#!/usr/bin/env bash
# 30+ malicious calls to ocarina-maint: every one must exit 2 (refused) or 3 (unsafe state), never 0/1.
# shellcheck disable=SC2016  # the literal $(…) is the attack being tested: it must NOT expand
# $1 = how to call it, split in words: "./system/usr/local/libexec/ocarina-maint" or "sudo -n /usr/local/libexec/ocarina-maint"
read -ra m <<<"${1:-/usr/local/libexec/ocarina-maint}"
pass=0; failn=0
t() { local d="$1"; shift; out=$("${m[@]}" "$@" 2>&1); rc=$?
  if [[ $rc -eq 2 || $rc -eq 3 ]]; then pass=$((pass+1)); printf 'ok   rc=%d  %-48s %s\n' "$rc" "$d" "${out:0:90}"
  else failn=$((failn+1)); printf 'MAL  rc=%d  %-48s %s\n' "$rc" "$d" "${out:0:90}"; fi; }
t "operación inexistente"                 rm -rf /
t "inyección con ; en la operación"        "health; id"
t "ruta como paquete"                      downgrade ../../etc/shadow
t "paquete con ; "                         downgrade 'bash;id'
t "paquete inexistente"                    downgrade paquete-que-no-existe-xyz
t "versión con \$()"                       downgrade bash '$(id)'
t "rollback con texto"                     rollback 1 'abc'
t "rollback con 0"                         rollback 0 5
t "rollback post < pre"                    rollback 50 40
t "rollback de un par que no es pre/post"  rollback 116 117
t "rollback con números negativos"         rollback -1 -2
t "rollback con 3 argumentos"              rollback 114 115 116
t "retener un paquete que no es kernel"    upgrade --hold glibc
t "upgrade con opción de pacman"           upgrade --overwrite '*'
t "snapshot con salto de línea"            snapshot $'hola\nadios'
t "snapshot con comillas y \$"              snapshot 'x"; $(id)'
t "fw-stage de un id con ruta"             fw-stage ../../x
t "scrub de otro dispositivo"              scrub start /dev/nvme0n1
t "paccache con argumentos"                paccache -rk0
t "argumento gigante"                      snapshot "$(printf 'a%.0s' {1..300})"
# fase 16
t "paccache con 0 versiones"               paccache 0
t "aur-build sin commit"                   aur-build google-chrome
t "aur-build con commit corto"             aur-build google-chrome abc123
t "aur-build con commit y \$()"             aur-build google-chrome '$(id)aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
t "aur-build de un paquete de los repos"   aur-build bash 0123456789abcdef0123456789abcdef01234567
t "aur-build de algo no instalado"         aur-build paquete-malo-xyz 0123456789abcdef0123456789abcdef01234567
t "aur-build con ruta como paquete"        aur-build ../../tmp/x 0123456789abcdef0123456789abcdef01234567
t "unit-restart de greetd"                 unit-restart greetd.service
t "unit-restart de systemd-logind"         unit-restart systemd-logind.service
t "unit-restart de una unidad que va bien" unit-restart cronie.service
t "unit-restart con ; "                    unit-restart 'x.service;id'
t "time-sync con argumentos"               time-sync --set 2000-01-01
echo "rechazadas: $pass · aceptadas por error: $failn"
[[ $failn -eq 0 ]]
