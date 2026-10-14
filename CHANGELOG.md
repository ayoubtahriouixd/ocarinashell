# Cambios

Formato de [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versiones con
[SemVer](https://semver.org/lang/es/). Para actualizar un kit instalado (conserva tu progreso):
`curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash -s -- --update`.

## [1.1.0] · 2026-10-14

**滑 Nameraka · vídeo fluido**: cualquier vídeo a pantalla completa hasta 120 fps con generación de fotogramas, como
Lossless Scaling. Especificado en el kit; lo construye Claude Code en la fase 11 B (que puede adelantarse).

### Añadido
- **滑 Fluido** en Engawa: ×2 · ×4 · ×6 · A medida (los fps que quieras) para lo que veas a pantalla completa en Chrome,
  Firefox, mpv o cualquier app; al apagarlo, todo como estaba. `Mod+Alt+F` y `Mod+Alt+Shift+F`.
- Motor **LSFG 3.1** de Lossless Scaling (lsfg-vk 2.0) y alternativa libre con IA (RIFE) tras una prueba de rendimiento.
- Diseño completo en `docs/01-ARQUITECTURA.md` §19 y tareas en la **fase 11 (parte B)**, que puede adelantarse.
- **Mockup 13** (Fluido sobre un vídeo), tarjeta Fluido en el mockup 02 y página 滑 en Ajustes.
- Skill **`/actualizar-kit`**: fusiona una versión nueva del kit con tu progreso.

### Cambiado
- `install.sh --update` sigue la rama `main` si aún no hay versiones publicadas y protege tus registros al fusionar.
- Las versiones se publican solas al subir una sección nueva a este fichero.

## [1.0.0] · 2026-10-14

Primera versión pública del kit.

### Incluye
- **Especificación completa**: visión, arquitectura, diseño, atajos, rendimiento, rescate, actualizaciones e ideas, y
  18 fases (00–17) con criterios de aceptación medibles.
- **12 mockups** a 2880×1800 con su fuente HTML/CSS: escritorio, Engawa, bloqueo, lanzador, energía, Shinobi, ajustes,
  Oni, Fune, Mamori, Snake y pantallas.
- **Logo** rojo sobre blanco: SVG estáticos y animados, PNG y componente QML verificado contra el SVG.
- **Arranque**: tema de Limine (oscuro y claro) probado con Limine 10.8.5 en QEMU y tema de Plymouth probado en
  plymouthd 24.
- **Datos y arte**: 7 temas con colores tradicionales japoneses (contraste WCAG AA comprobado), 6 fondos y 6 sonidos
  originales, 72 microestaciones, 42 proverbios, glosario kanji y 105 kaomoji.
- **Brillo independiente por monitor**: DDC/CI con atenuación por software de respaldo.
- **13 ideas extra** integradas en las fases ([docs/07-IDEAS.md](docs/07-IDEAS.md)).
- **Claude Code**: `CLAUDE.md`, permisos, skills (`/fase`, `/estado`, `/pulir`, `/auditar`, `/actualizar`, `/mantener`,
  `/rescate`), agentes y hook de guardia con 201 pruebas.
- **Instalador** `install.sh` para `curl`: comprueba el equipo, instala o actualiza el kit y ofrece el sudo temporal de
  la construcción.
- **Mantenimiento autónomo** 守 Mamori con la IA local 蛇 Snake (especificado; se construye en las fases 15 y 16).

[1.1.0]: https://github.com/ayoubtahriouixd/ocarinashell/releases/tag/v1.1.0
[1.0.0]: https://github.com/ayoubtahriouixd/ocarinashell/tree/cae125d
