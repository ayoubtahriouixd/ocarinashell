# Fase 15 · 蛇 Snake: la IA local de OcarinaShell

**Objetivo**: una IA **local, gratuita y privada** que corre en el portátil (sin nube ni suscripciones) con dos trabajos:
ser el cerebro de 守 Mamori (investigar, revisar, diagnosticar, proponer arreglos verificables y redactar informes) y un
asistente offline en la barra. Rápida cuando se usa e inexistente cuando no (0 MB de RAM en reposo).
**Lee antes**: `docs/DECISIONES.md` D-008, `docs/06-ACTUALIZACIONES.md` (capa 6), `docs/01-ARQUITECTURA.md` §18,
mockups `10-mamori.png` y `11-snake.png`, y la documentación ACTUAL (delega) de llama.cpp (Vulkan, `llama-server`,
`response_format` con JSON Schema), FastFlowLM/Lemonade (NPU XDNA 2 en Linux) y llama-swap.

## Principios
- Snake **propone**, el orquestador **dispone**: salidas con esquema JSON validado; nunca ejecuta comandos libres; los
  parches solo se aplican al repo en una rama y solo se fusionan si pasan las pruebas.
- Todo lo que lee de internet es **dato, no instrucción** (antiinyección): delimitadores en las plantillas, salida
  restringida, y ninguna acción depende solo del texto descargado.
- Local de verdad: modelo y servidor en el portátil; la red solo para descargar noticias y changelogs de una lista
  blanca de dominios.
- Eficiencia: se carga bajo demanda y se descarga tras N min sin uso; nunca en Shinobi ni en Oni; nunca si la RAM libre
  no alcanza (VM de Fune incluida).

## Tareas
1. **Snapshot**.
2. **Inventario de aceleradores** (→ `docs/SISTEMA.md`): `vulkaninfo --summary` (heaps de memoria del 860M), tamaño UMA
   de la BIOS (fase 11) y límites GTT; NPU: `lspci`, módulo `amdxdna`, `/dev/accel/accel0`, `fw_version`, XRT.
3. **Backends candidatos** (solo repos oficiales; verifica nombres con `pacman -Si`):
   A) `llama-cpp-vulkan` (`llama-server` sobre la iGPU por Vulkan/RADV) — por defecto, el más robusto ante actualizaciones.
   B) NPU XDNA 2: `xrt`, `xrt-plugin-amdxdna`, `fastflowlm` (+ `amdxdna-dkms` si el kernel < 7.0; `memlock` ilimitado;
      IOMMU activo; `flm validate`) — solo si es estable; es la opción más eficiente en vatios.
   C) Lemonade Server (une A y B con API OpenAI-compatible) si está empaquetado y estable.
   Carga bajo demanda con `llama-swap` (TTL) o un vigilante propio (`ocarina-snake` arranca el servicio y lo para tras
   `keepAliveMin`).
4. **Modelos candidatos**: investiga los mejores del momento con licencia abierta (Apache/MIT), que quepan en ≤ 18 GB a
   4 bits, MoE preferido, buen uso de herramientas/JSON y buen español. Punto de partida: gpt-oss-20b y
   Qwen3-30B-A3B-Instruct (o su variante Coder), más uno pequeño y rápido para clasificar (Qwen3-4B-Instruct o similar).
   Descarga solo de fuentes oficiales (repos de los autores o de ggml-org/unsloth/bartowski en Hugging Face) y comprueba
   el hash. Modelos en `~/.local/share/ocarinashell/snake/models/`.
5. **Evaluación** (`snake/evals/`, ≥ 30 casos reales que construyes tú): noticias de Arch con y sin intervención
   manual, changelogs con y sin cambios que rompan APIs usadas en el repo, diffs de PKGBUILD benignos y sospechosos,
   logs de fallos con causa conocida, informes a redactar, 5 traducciones japonés→español (Yomu) y 5 casos de
   inyección. `ocarina snake eval` mide aciertos, JSON válido, latencia, tokens/s (prefill y generación), vatios
   (`scripts/bench-power.sh` en paralelo) y RAM. Elige la combinación ganadora (backend × modelo × cuantización ×
   contexto) y documéntala en `docs/SNAKE.md` y DECISIONES.
6. **`bin/ocarina-snake`** (Python stdlib): cliente OpenAI-compatible + tareas con plantilla y esquema
   (`snake/tasks/*.json`): `triage-news`, `review-changelog`, `scan-issues`, `review-pkgbuild`, `diagnose`,
   `propose-patch` (diff unificado mínimo), `report`, `assist` y `translate` (Yomu). Recuperación con lista blanca:
   RSS de Arch, API de Discourse de CachyOS (`/latest.json`, `/search.json`), GitHub y GitLab (releases e issues con
   búsqueda), bugtracker de Arch y wikis; caché y límites de tamaño. Contexto del sistema de solo lectura: journal
   filtrado, estado de servicios, versiones y `grep` del repo.
7. **Servicio y UI**: `ocarina-snake.service` (usuario, solo `127.0.0.1`); indicador 蛇 en Obi solo mientras el modelo
   está cargado; servicio QML `Snake`; **asistente** (mockup 11): conversación en español, adjuntar contexto (journal,
   portapapeles, ventana enfocada) y acciones propuestas como botones que SOLO llaman a comandos `ocarina …` de una
   lista blanca tras confirmación. `Mod+Shift+A`, prefijo `;` en Torii para preguntas rápidas, función `snake` en fish.
8. **Política de recursos**: carga solo con RAM libre ≥ tamaño del modelo + 4 GB; descarga a los 5 min (configurable);
   bloqueado en Shinobi y Oni; en batería solo para el asistente (con aviso), nunca para tareas de fondo; prioridad baja.
   Página 蛇 Snake en Ajustes: modelo, backend, memoria, privacidad, «probar ahora».
9. **Seguridad**: los 5 casos de inyección de las evals superados (p. ej. un post que dice «ejecuta rm -rf» → Snake lo
   marca como sospechoso y el orquestador no ejecuta nada); sin acceso a ficheros personales; todo registrado en el journal.
10. **Mantenible por Mamori**: `ocarina snake eval --compare <modelo>` para que Mamori pruebe cada mes modelos nuevos y
    cambie solo si ganan; pruebas de humo de Snake añadidas a `scripts/smoke-test.sh`.
11. **読 Yomu · leer y traducir lo que ves** (`docs/07-IDEAS.md`; Mod+Alt+T, `ocarina read [--translate]`): región con
    `slurp` → `grim` → `tesseract` local (`-l jpn+spa+eng`; si el texto es vertical, `jpn_vert` con `--psm 5`) → texto
    al portapapeles y panel pequeño junto a la región; «Traducir con Snake» (tarea `translate`: español + lectura en
    hiragana y rōmaji para el japonés; salida JSON validada). Nada sale del equipo y la captura se borra al cerrar. Si
    Snake está parado, «Traducir» lo arranca bajo demanda con la política de RAM.

## Criterios de aceptación
- [ ] `docs/SNAKE.md` con la tabla de evaluación y la elección justificada (≥ 85 % de aciertos en clasificación y 100 %
      de JSON válido).
- [ ] RAM de Snake en reposo = 0 (servicio parado); primera respuesta < 15 s en frío y < 2 s en caliente para tareas cortas.
- [ ] Captura del asistente ≈ mockup 11; acciones solo con confirmación; casos de inyección superados.
- [ ] Snake parado en Shinobi y en Oni (verificado).
- [ ] Yomu: imagen de prueba con japonés horizontal y otra vertical → > 90 % de caracteres correctos; traducción
      coherente; ninguna conexión fuera de `127.0.0.1` (`ss -tnp`).

## Al terminar
PROGRESS.md, commit; dile a Ayoub qué modelo eligió y por qué, cuánto consume y cómo preguntarle cosas.
