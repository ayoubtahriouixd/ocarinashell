# Fase 06 · Kagi (bloqueo), inactividad, Dengen (energía), polkit y greeter opcional

**Objetivo**: la pantalla de bloqueo más bonita que Ayoub haya visto —y la más fiable—, gestión de inactividad,
menú de energía y diálogo polkit propios. **Fase crítica de seguridad: sigue el orden al pie de la letra.**
**Lee antes**: mockups 03 y 05, `docs/02-DISENO.md` §5, `docs/05-RESCATE.md`, documentación de Quickshell
WlSessionLock/WlSessionLockSurface, PamContext, IdleMonitor, IdleInhibitor, PolkitAgent/AuthFlow, Greetd.

## Orden obligatorio
1. **Snapshot** + confirma `swaylock` instalado y que `ocarina lock` (respaldo) funciona con la shell parada.
2. **PAM aislado primero**: `shell/pam/password.conf` (p. ej. `auth include system-local-login` o lo que use
   CachyOS para el login local; verifícalo en `/etc/pam.d/`) y, si hay lector y Ayoub quiso, `fingerprint.conf`
   (`auth sufficient pam_fprintd.so`). Prueba `PamContext` en una ventana normal de prueba (no bloqueo) con su
   contraseña real tecleada por él: éxito, fallo, cancelación, huella. Solo cuando eso sea sólido, sigue.
3. **Modo prueba** (`ocarina lock test` → IPC `lock.test()`): la MISMA interfaz del bloqueo en una capa `Overlay` de
   pantalla completa (no `WlSessionLock`) que se cierra con Esc y se desbloquea sola a los 60 s. Toda la iteración
   visual y las capturas se hacen aquí.
4. **Bloqueo real** solo con Ayoub delante (pregúntale antes): bloquea, que desbloquee; repite 20 veces alternando
   contraseña y huella; prueba contraseña errónea. Verifica también el procedimiento de rescate de 05-RESCATE
   (TTY → relanzar la shell o `swaylock`) con él delante y anota el resultado real.

## Kagi — diseño (mockup 03)
- Composición asimétrica: columna izquierda (marca + `お帰りなさい、Ayoub` · fecha kanji · reloj 196/200 con
  `Text.CurveRendering` · fecha en español + tiempo + 七十二候 · campo de contraseña · pistas) y a la derecha el
  proverbio del día en 縦書き (cada carácter en columna; romaji vertical; sello 殻; traducción). Mini reproductor
  abajo-izquierda. Wi-Fi y batería arriba-derecha. Fondo: el de pantalla pre-difuminado + viñeta (sin blur en vivo).
- **La ocarina suena**: cada tecla ilumina el siguiente agujero de `OcarinaLogo` (`press(i)`: el agujero se enciende y
  las ondas laten) ; los caracteres son pétalos que aparecen con un pequeño giro; borrar hace caer el último pétalo.
  Error → `shake()` (tiembla 300 ms y las ondas se vuelven grises un momento), «Contraseña incorrecta», tras 3 fallos
  espera creciente. Éxito → `burst()` (estallido de ondas) + sonido `unlock` + la superficie se disuelve (300 ms) y se
  libera el bloqueo. Las tres funciones ya están en el componente verificado (no lo edites: se regenera con
  `tools/qml_logo_gen.py`); con `animated: false` no hacen nada.
- Mayúsculas activadas: aviso (lee `/sys/class/leds/input*::capslock/brightness`). Distribución de teclado visible.
- Notificaciones en el bloqueo: solo contador (o contenido si Ayoub lo permite en Ajustes).
- Varias pantallas: todas bloqueadas; las secundarias muestran solo el reloj.
- Ahorro: tras 30 s sin actividad en el bloqueo, apaga monitores (`niri msg action power-off-monitors`); cualquier
  tecla los enciende. Animaciones de reposo del bloqueo apagadas cuando la pantalla está apagada o en Shinobi.
- 保護 Hogo (`oled.lockDrift`): mientras se ve, la composición entera deriva hasta ±6 px lógicos, un paso por minuto
  con el tic del reloj (nunca durante la entrada ni con la contraseña a medio escribir).

## Inactividad (`Idle`)
`IdleMonitor`s con perfiles CA/batería de Ajustes (por defecto CA: atenuar 4 min, bloquear 5, apagar pantalla 6,
suspender nunca · batería: 2, 3, 4, 15). Atenuar = bajar brillo al 30 % en TODAS las pantallas (interna y software
con fundido; DDC en 1–2 escrituras, sin fundido porque es lento) y restaurar al moverse cada una a su valor.
`respectInhibitors: true` (vídeos). Mosaico «Despierto» = `IdleInhibitor`. `ocarina-sleep.service` con
`swayidle -w before-sleep 'ocarina lock --wait' lock 'ocarina lock'`: comprueba que tras suspender/reanudar NO se ve
el escritorio ni un instante (tapa del portátil incluida). Expón también «inactivo ≥ 15 min» como señal para el disparo
oportunista de 守 Mamori (fase 16).

## Dengen (mockup 05)
Tarjetas 鍵 眠 退 再 終 (Yuji Syuku), teclas L S E R P, flechas, Enter; las destructivas (cerrar sesión, reiniciar,
apagar) exigen **mantener** Enter/clic 1,2 s mientras la tarjeta se llena de tinta. Acciones: `ocarina lock`,
`systemctl suspend`, `niri msg action quit --skip-confirmation` (solo aquí, ejecutado por el usuario),
`systemctl reboot`, `systemctl poweroff`. Saludo según la hora (お疲れさま / おやすみなさい). Botón físico de encendido → Dengen.
Deja el hueco para «Actualizar y reiniciar» (lo activa Mamori cuando hay un reinicio pendiente).

## 復元 Fukugen · restaurar la sesión (`docs/07-IDEAS.md`)
Servicio `Session` (ajuste `session {restore: ask|auto|off, exclude[]}`): guarda
`~/.local/state/ocarinashell/session.json` (por ventana: app-id, entrada `.desktop`, espacio (índice y nombre), salida,
ancho de columna, flotante y tamaño) con cada apertura/cierre de ventana agrupando 30 s (eventos de niri, sin sondeo;
así sobrevive a un corte de luz) y siempre en la despedida de Dengen. Al entrar: aviso «¿Restaurar tu sesión? · 7 apps ·
Restaurar / Ahora no». Relanza con `DesktopEntries` (máx. 3 a la vez) y coloca cada ventana al aparecer
(`WindowOpenedOrChanged`) con las variantes por id de tu versión de niri (`--window-id`/`--id`: `move-window-to-monitor`,
`move-window-to-workspace --focus false`, `set-window-width`; compruébalo con `niri msg action <acción> --help`; si alguna
no lo admite, enfoca esa ventana un instante, aplica y devuelve el foco); lo que no aparezca en 20 s se ignora. Por
defecto excluye apps de Fune, juegos, ventanas `ssh · *` (nunca reconecta a servidores al iniciar sesión) y `wl-mirror`;
las terminales se reabren en la carpeta de su título (fish la pone en el título de Ghostty).

## Polkit
`PolkitAgent` con diálogo propio (vidrio, icono de la acción, mensaje, campo de contraseña con pétalos, detalles
plegables, Cancelar). Asegura que no hay otro agente registrado. Prueba: `pkexec true`, `pkexec ocarina-powerctl …`
(fase 10), instalación con pacman desde una app gráfica si la hay.

## Greeter (solo si Ayoub lo eligió en la fase 0)
greetd + niri mínimo (`system/greetd/niri-greeter.kdl`) que lanza `qs -p /usr/share/ocarinashell/greeter/shell.qml`
(componentes compartidos con Kagi; usuario Ayoub preseleccionado; sesión niri; sonido `startup`). Requisitos:
snapshot, TTY de rescate verificada, `agreety` como respaldo en la config de greetd, prueba con el servicio sin
habilitar primero (`sudo greetd --config …` en una TTY) y habilitar solo con su permiso. Si algo falla: desactivar
greetd y volver al gestor anterior (05-RESCATE). Diseño pensado para la fase 13: el greeter arranca con el fondo de
Plymouth y el icono en la misma posición/tamaño (centro a 42 % del alto, 380 px físicos a 1800 p) y desde ahí anima
hacia su composición (la del bloqueo), para que el paso Plymouth → greeter sea invisible.

## Criterios de aceptación
- [ ] Capturas del modo prueba ≈ mockup 03 y Dengen ≈ mockup 05 (visual-qa).
- [ ] 20 bloqueos/desbloqueos reales sin fallo; contraseña errónea bien gestionada; huella si aplica.
- [ ] Suspender/reanudar ×3 (tecla y tapa) sin destello del escritorio; temporizadores de inactividad verificados con
      valores cortos de prueba y restaurados después.
- [ ] Diálogo polkit funcionando; ningún otro agente activo. Greeter (si aplica) probado con reinicio real pedido a Ayoub.
- [ ] Fukugen: 6 apps en 3 espacios y 2 anchos → reiniciar la shell y simular el inicio de sesión (`ocarina session
      restore`) → cada una vuelve a su espacio y ancho.

## Al terminar
PROGRESS.md, commit, y recuerda a Ayoub el procedimiento de rescate en 3 líneas.
