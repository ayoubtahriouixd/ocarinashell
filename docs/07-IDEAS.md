# 07 · Ideas de Claude アイデア

> Ayoub: «pon también tus ideas». Estas son las mías, pensadas para su equipo (OLED táctil, monitores externos), su
> trabajo (administración de sistemas) y su gusto (Japón, anime). Todas cumplen lo mismo: 静 en reposo no gastan nada
> (ni sondeos ni `Timer` propios), se apagan en Settei, se ocultan con una pista si falta su paquete y 守 Mamori puede
> mantenerlas. Todas están hechas; la columna «Fase» dice en qué fase de la construcción se hicieron (el detalle, en
> `docs/historia/fases/`); aquí, el porqué.

| | Idea | Qué hace | Por qué | Fase | Por defecto |
|---|---|---|---|---|---|
| 保護 | **Hogo** · cuidado del OLED | Barra e isla se desplazan 2 px físicos cada 15 min y bajan al 80 % tras 3 min sin usarlas; el bloqueo deriva despacio | Tu panel es OLED: una barra fija horas en el mismo píxel puede dejar marca. Invisible y gratis (va con el tic del reloj) | 03 · 06 · 07 | sí |
| 配置 | **Haichi** · pantallas | Organizador visual (arrastrar, escala, Hz, rotación, principal), perfiles que se aplican solos al conectar (家 Casa, 職 Oficina), aviso al conectar, tapa cerrada = todo al monitor | niri no trae interfaz para esto (hoy sería editar KDL a mano); completa el brillo por pantalla | 07 | sí |
| 発表 | **Happyō** · presentar | «Duplicar» con `wl-mirror` (niri no clona salidas) + No molestar + Despierto + avisos sin contenido | Reuniones y proyectores sin que aparezca nada privado | 07 | a mano |
| 控 | **Hikae** · copias de `~` | Snapshots de snapper de `@home` cada hora (24 horarios, 7 diarios, 4 semanales); `ocarina backup restore` o Ajustes › 守 › 控 Copias recuperan en `~/Restaurado/` sin sobrescribir ni pedir root | «Nunca romperse» incluye no perder datos. Empezó como `restic` a USB/NAS; Ayoub prefirió snapshots ligeros (D-070): cubren borrados y errores, no un disco muerto ni un robo | 14 · 16 | con `scripts/root/fase-14.sh` |
| 復元 | **Fukugen** · restaurar sesión | Recuerda qué apps había en cada espacio, pantalla y ancho; al entrar, «¿Restaurar 7 apps?» y las recoloca | niri no restaura sesiones; tras un reinicio (o uno de Mamori) todo vuelve a su sitio | 06 | preguntar |
| 本番 | **Honban** · SSH sin sustos | Hosts de `~/.ssh/config` en Torii (`~`); los de producción abren con anillo rojo sólido, borde y sello 本番 en la barra | Eres admin: ver de un vistazo que esa terminal es producción evita el error clásico | 05 · 08 | sí |
| 色 | **Iro** · cuentagotas | Mod+Alt+P: color de cualquier píxel (`niri msg pick-color`) en `#hex`/`rgb`/`oklch` + el color tradicional japonés más cercano | Útil y muy OcarinaShell: los 伝統色 ya están en `colores-nippon.json` | 05 | sí |
| 集中 | **Shūchū** · modo foco | Bloques de 25/50 min: anillo y minutos en la isla, No molestar, nota de ocarina y 休憩 al acabar | Concentración sin apps extra; cero CPU (minuto a minuto) | 04 | a mano |
| 読 | **Yomu** · leer y traducir | Mod+Alt+T: zona de pantalla → OCR local (japonés horizontal/vertical, español, inglés) → texto copiado; «Traducir con Snake» da español + lectura | Japonés de anime, manga, juegos o webs, sin nube | 15 | a mano |
| 顔 | **Kaomoji** | `:` en Torii busca kaomoji por palabra en español («mesa» → (╯°□°)╯︵ ┻━┻) | Puro anime y coste cero (`assets/data/kaomoji.json`) | 05 | sí |
| 指 | **Gestos táctiles** | Arrastrar hacia abajo desde el clúster abre Engawa siguiendo el dedo; desde la isla, 広場 Hiroba; desde 蛇 o 船, su panel; deslizar la isla cambia de canción | Tu pantalla es táctil y en Linux casi nadie lo aprovecha | 04 | sí |
| 縁 | **Detalles de Engawa** | Compartir el Wi-Fi con un QR, mosaico VPN si hay WireGuard/VPN en NetworkManager, relojes del mundo (los mostraba Koyomi; 広場 Hiroba, que lo sustituye, todavía no los enseña) | Cosas pequeñas que se usan cada semana | 04 | sí |
| 昼夜 | **Tema y brillo según la hora** | Tema claro de día y oscuro de noche (pareja a elegir); brillo de cada pantalla con curva día/noche que se pausa si lo tocas | Apagado: a mucha gente le molesta que cambie solo | 07 | no |

## Paquetes (todos de los repos oficiales)
`./install.sh` pone `wl-mirror` (Happyō, grupo base) y `tesseract` + `tesseract-data-jpn`, `-jpn_vert`, `-spa`, `-eng`
(Yomu, grupo Snake); ver `scripts/paquetes.txt`. `qrencode` (QR del Wi-Fi) es opcional: sin él, Engawa dice «Falta
qrencode». `niri msg pick-color` existe desde niri 25.05. Hikae ya no necesita `restic` (D-070).

## Descartadas (y por qué)
- Fondos animados o «vivos»: gastan batería sin aportar (anti-objetivo de 00-VISION).
- Widgets sobre el escritorio: en niri el fondo casi nunca se ve; la información ya vive en la isla, Engawa y Hiroba.
- Recordatorio 20-20-20 para la vista: interrumpe; Shūchū marca descansos cuando tú quieres.
- Sincronizar ajustes en la nube: privacidad; el repo git y Hikae ya son tu copia.
- Brillo con `ddcci-driver-linux` o con la rampa de gamma: ver D-009.

Decisión registrada en `docs/DECISIONES.md` (D-010). Si alguna no te convence, se apaga en Settei.
