# Cambios

Formato de [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versiones con
[SemVer](https://semver.org/lang/es/). Para actualizar un kit instalado: `bash ~/ocarinashell/install.sh --update`.

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

[1.0.0]: https://github.com/ayoubtahriouixd/ocarinashell/releases/tag/v1.0.0
