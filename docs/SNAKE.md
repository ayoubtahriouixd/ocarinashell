# 蛇 Snake — la IA local de OcarinaShell

IA de pesos abiertos que corre en el portátil, sin nube, sin cuentas y sin suscripciones (D-008). Tiene dos trabajos:
ser el cerebro de 守 Mamori (investigar, revisar, diagnosticar, proponer arreglos verificables, redactar informes) y un
asistente en la barra. **0 MB en reposo**: el servidor solo existe mientras se usa.

Para empezar: marca el grupo **蛇 Snake** en el instalador (llama.cpp con Vulkan, whisper.cpp y el OCR de Yomu) y
descarga los modelos: `ocarina-snake models pull gpt-oss-20b` (12 GB, el principal) y, para la voz,
`ocarina-snake models pull whisper` (548 MiB). Opcional, para cuando la GPU va justa: `… pull qwen3.5-4b` (2,7 GB).
`ocarina snake status` dice qué hay y si puede cargarse ahora.

## Cómo se usa
| Dónde | Qué |
|---|---|
| `Mod+Shift+A` o el 蛇 de la barra | El asistente (mockup 11): pregunta, adjunta contexto con `•••` (journal 12 h, red, Mamori, Shinobi, portapapeles, ventana), acciones con «Ejecutar» |
| 声 `Mod+Alt+A`, el micro del panel o `Ctrl+Espacio` | Por voz: graba hasta una pausa de 1,3 s (máx. 30 s; otra vez = parar, `Esc` = descartar), transcribe con **whisper large-v3-turbo** (whisper.cpp, q5_0, 548 MiB, sha256 fijado; `ocarina-snake models pull whisper`) y pregunta. Vulkan ≈ 1,3 s por 7 s de voz si quedan ≥ 4 GiB de GPU libres; si no, CPU con el contexto de audio recortado (~5 s). El audio solo existe en `$XDG_RUNTIME_DIR` y se borra al instante. La NPU (FastFlowLM `whisper-v3:turbo`) necesitaría memlock ilimitado y un servidor TCP: no compensa (D-085) |
| Torii, prefijo `;` | `;¿por qué va lento el wifi?` → abre el asistente con la pregunta |
| fish | `snake "¿cómo silencio el micro?"` · `journalctl -b -p warning \| snake "¿qué falla?"` (lo que entra por la tubería es contexto) |
| `Mod+Alt+T` | 読 Yomu: elige una zona → OCR local → texto copiado → «Traducir con Snake» (español + hiragana + rōmaji) |
| CLI | `ocarina snake status · start · stop · eval · models · fetch · actions` (`ocarina-snake help`) |
| Ajustes › 蛇 Snake | Modelo, motor, contexto, tiempo de descarga, batería, privacidad, «Probar ahora» |

## Arquitectura
```
shell (Snake.qml, SnakePanel, Yomu.qml)      Mamori                fish / Torii
            │  ocarina-snake assist|translate|task (JSON por líneas)  │
            └──────────────────────┬────────────────────────────────┘
                bin/ocarina-snake (Python stdlib): política, plantillas, esquema, validación, journal
                                   │ socket Unix $XDG_RUNTIME_DIR/ocarinashell/snake/llama.sock (API OpenAI)
              ocarina-snake.service → «ocarina-snake serve» (vigilante) → llama-server (Vulkan, iGPU)
                                                  (la NPU, flm serve, solo para `eval --external`)
```
- **Bajo demanda**: `start` comprueba la política y arranca la unidad; `serve` lanza `llama-server` y lo para a los
  `snake.keepAliveMin` minutos sin uso (5 por defecto), al entrar en 忍 Shinobi o 鬼 Oni, o si la RAM libre baja de
  1,5 GiB. Nunca corta una respuesta a medias (mira `/slots`). La unidad sale → 0 MB.
- **Política** (`policy()`): Snake activado · ni Shinobi ni Oni · con batería solo el asistente (con aviso), las tareas
  de fondo esperan al cargador · RAM libre ≥ la del modelo + 4 GiB (la VM de Fune cuenta porque ocupa RAM real).
- **Prioridad baja**: `Nice=5`, `CPUWeight=60`, E/S best-effort 6: el escritorio sigue fluido mientras piensa.
- **Confinamiento**: `ProtectSystem=strict`, `ProtectHome=read-only` (solo escribe su directorio de `$XDG_RUNTIME_DIR`),
  `PrivateNetwork=yes` (la unidad no tiene más red que su propio loopback), `NoNewPrivileges`. llama-server escucha
  en un **socket Unix** en un directorio 0700: ningún otro equipo, contenedor ni página del navegador puede usarlo (un
  puerto TCP en 127.0.0.1 sí lo era, con CORS abierto). `IPAddressDeny=` no sirve en una unidad de usuario: systemd lo
  ignora sin root (lo detectó el perf-auditor). Las fuentes de la lista blanca las lee el CLI, fuera de la unidad.
- **GPU**: modelo + 1 GiB + 3 GiB para el escritorio ≤ VRAM+GTT libres, `--fit` y descarga si la GPU baja de 1 GiB
  (ver «Memoria de GPU»).
- **Al abrir el asistente** (enchufado) el modelo empieza a cargar y lee el prompt fijo mientras escribes.

## Snake propone, el orquestador dispone
- **Tareas fijas** (`snake/tasks/*.json`, generadas por `tools/snake_tasks.py`): `triage-news`, `review-changelog`,
  `scan-issues`, `review-pkgbuild`, `diagnose`, `propose-patch`, `report`, `assist`, `translate`. Cada una con su
  plantilla en español y un **esquema JSON estricto**: el servidor restringe la salida (`response_format` json_schema,
  gramática) y `ocarina-snake` la valida otra vez. Si no cumple → código 6 y nadie actúa.
- **Antiinyección**: todo lo que viene de internet, del sistema o del usuario va entre delimitadores con una etiqueta
  aleatoria por petición (`<<<DATOS-3FA9C1 …>>>`) que el texto no puede conocer; la plantilla manda tratarlo como dato y
  marcar `suspicious` si intenta dar órdenes. Ninguna salida tiene un campo «comando»: no hay nada que ejecutar.
- **Acciones del asistente**: solo ids de `snake/actions.json` (lista cerrada, todo `ocarina …` y reversible). El
  esquema de `assist` limita `action.id` a esa lista; la shell muestra el comando y solo `run-action <id> --confirmed`
  (tras pulsar «Ejecutar») lo lanza, comprobando otra vez la lista.
- **Parches** (`propose-patch`): diff unificado mínimo; Mamori lo aplica en una rama, pasa las pruebas y solo
  entonces fusiona.
- **Recuperación** (`ocarina-snake fetch`): https y solo dominios de `snake/sources.json` (Arch, CachyOS, GitHub,
  GitLab de Arch/freedesktop/GNOME, wikis y docs de Quickshell/niri/Ghostty/Neovim); las redirecciones fuera se
  rechazan; 2 MB por descarga; caché de 1 h en `~/.cache/ocarinashell/snake/fetch`.
- **Contexto del sistema** (`ocarina-snake context`): journal filtrado (warning+), unidades fallidas, versiones, `git
  grep` del repo, estado de energía y red. **Nunca** ficheros personales; contraseñas, tokens y hashes se ocultan.
- **Registro**: todo en el journal: `journalctl -t ocarina-snake` (tareas, adjuntos, acciones propuestas y ejecutadas).

## Modelos
Solo de los repositorios oficiales (`ggml-org`, `unsloth`, `google`), con la revisión fijada y el **sha256** de Hugging
Face comprobado tras la descarga (`snake/models.json`, `ocarina snake models pull|verify`). Licencia Apache-2.0 todos.
Ficheros en `~/.local/share/ocarinashell/snake/models/`.

**Modelo ligero automático.** Si el principal no cabe ahora en la memoria libre de la GPU (regla de abajo; lo típico: un
navegador con vídeo ocupándola), el asistente no se niega: usa el mejor modelo ligero ya descargado que sí quepa
(qwen3.5-9b, luego qwen3.5-4b; 86,8 y 84,2 % en la evaluación) y lo deja escrito en el journal y en la «política» de
`ocarina snake status`. Si ya hay uno ligero cargado, sigue con él. Las tareas de fondo de Mamori **nunca** bajan de
modelo: esperan al principal, con el que se midieron sus aciertos.

## Resultados (2026-10-17, 38 casos, `ocarina-snake eval`)

Perfil de energía «Ahorro» enchufado (el de Ayoub), contexto 16 384, llama.cpp 0.6.0 + ggml-vulkan (RADV, Radeon 860M).
Clasificación = noticias + changelogs + PKGBUILD + issues (21 casos); inyección = 6 casos; diagnóstico = diagnose,
report y patch; traducción = 5 frases japonesas.

| Modelo · motor | Total | Clasif. | Inyección | Traduc. | Diagn. | JSON válido | Generación | Latencia media / p95 | Frío | Memoria cargado |
|---|---|---|---|---|---|---|---|---|---|---|
| **gpt-oss-20b · Vulkan** ✅ | 94,7 % | **95,2 %** | **100 %** | 80 % | 100 % | **100 %** | 10,1 tok/s | 28 s / 50 s | 12 s | ~12 GiB (GPU) |
| gemma-4-26b-a4b · Vulkan | 97,4 % | 95,2 % | 100 % | 100 % | 100 % | 100 % | 10,0 tok/s | 25 s / 43 s | 17 s | ~20 GiB — **no cabe con margen** |
| qwen3.5-9b · Vulkan | 86,8 % | 85,7 % | 100 % | 80 % | 83 % | 100 % | 4,5 tok/s | 59 s / 87 s | 4 s | ~8 GiB |
| qwen3.5-4b · Vulkan | 84,2 % | 90,5 % | 67 % | 80 % | 83 % | 100 % | 7,8 tok/s | 35 s / 60 s | 3 s | ~6 GiB |
| qwen3.5-4b · NPU (FastFlowLM) | 0 % | — | — | — | — | **0 %** | — | 15 s / 39 s | — | 3,2 GB |
| qwen3.6-35b-a3b · Vulkan | — | — | — | — | — | — | — | — | — | **agota la GTT** |

**Elegido: gpt-oss-20b en Vulkan.** Cumple los dos umbrales (≥ 85 % de clasificación, 100 % de JSON válido), resiste
las 6 inyecciones (en una repetición, el log con `curl … | sudo sh` no se marcó como sospechoso, aunque tampoco recomendó el comando: el validador y la lista blanca de acciones son la red de seguridad), es el más rápido y es el que deja más memoria de GPU libre de los buenos (5 GiB con él cargado).
gemma iguala o mejora la calidad, pero con 14,4 GB de pesos deja la GPU a < 1,5 GiB del límite: con un vídeo o Chrome
abiertos la sesión entera estaría en riesgo (ver más abajo). Los fallos de gpt-oss: un changelog de Quickshell que no
marca como «rompe algo» y una frase coloquial de anime («もう諦めた») traducida sin el matiz de rendirse.

- **Tiempos**: cargar el modelo 11–12 s. Pregunta en frío sin cargar antes: ~11 s + ~5 s hasta la primera palabra
  (> 15 s); por eso el panel empieza a cargar al abrirse y la espera se solapa con lo que escribes. En caliente la
  primera palabra llega en **~3 s** (no < 2 s): la pregunta solo añade ~35 tokens (lo fijo, acciones incluidas, sale
  de la caché del servidor) y gpt-oss razona unas decenas de tokens que no deja quitar. En «Equilibrado» apenas cambia (prefill +30 %, generación +10 %). Con
  qwen3.5-4b sin razonamiento: 2,2 s, a cambio de peor resistencia a la inyección (D-074).
- **Por qué todo va a ~10 tok/s**: el portátil tiene un solo módulo DDR5-5600 (un canal, ~45 GB/s). Generar un token
  lee todos los pesos activos de memoria, así que el ancho de banda manda: la GPU apenas gana a la CPU y un MoE con
  pocos parámetros activos (gpt-oss: 3,6 B) es lo que mejor aprovecha la máquina. Un segundo módulo doblaría la velocidad.
- **Consumo**: 0 MB y 0 procesos en reposo (unidad parada). Cargado y respondiendo, el SoC se queda en su límite del
  perfil Ahorro (13,0 W de media, pico 13,3 W, unos 2–4 W por encima del escritorio en reposo). La NPU se queda en 11,7 W.
- **NPU**: FastFlowLM 1.0.9 funciona (validado, firmware 1.1.2.64), pero no acepta `response_format`: inventa sus
  propios campos y ninguna salida pasa el esquema. Queda como motor opcional en Ajustes, solo para evaluar; necesita
  memlock ilimitado, un cambio de root que el repo no trae hecho (no hace falta para usar Snake).

### Memoria de GPU: regla dura
En esta APU la VRAM (4 GiB) y la GTT (13,5 GiB) son RAM del sistema, pero la GTT es un límite del kernel: si un proceso
la agota, **todos** los clientes de la GPU fallan al enviar trabajo. Al cargar qwen3.6-35b-a3b (17,7 GB) cayeron
llama-server, Ghostty, Xwayland, qs y niri. `--fit` de llama.cpp no lo evita: las capas que deja en la CPU van en búferes
pinned, que también cuentan como GTT. Por eso Snake solo carga un modelo si **pesos + 1 GiB + 3 GiB para el escritorio ≤
VRAM + GTT libres**, y el vigilante lo descarga si la GPU baja de 1 GiB libre, aunque esté a mitad de una respuesta.

