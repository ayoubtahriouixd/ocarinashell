# Licencia y condiciones de uso de OcarinaShell

**OcarinaShell (オカリナシェル) · Created by Ayoub** · © 2026 Ayoub

## 1. El código: GPL-3.0-or-later

El código de OcarinaShell (QML de `shell/`, `bin/`, `lib/`, `native/`, `scripts/`, `greeter/`, `config/`, `templates/`,
`system/`, `tools/`, `tests/`) es software libre bajo la **GNU General Public License, versión 3 o posterior**
(texto completo en [`LICENSE`](../LICENSE)).

En la práctica, puedes:
- usarlo para lo que quieras, también en tu trabajo;
- estudiarlo y modificarlo;
- compartirlo, con cambios o sin ellos.

A cambio, si **distribuyes** una versión (modificada o no), debes hacerlo con la misma licencia, con el código fuente y
manteniendo este aviso de autoría. Usarlo y cambiarlo en tu propio equipo no te obliga a nada.

## 2. El arte: CC BY-SA 4.0

El arte original (fondos, iconografía, sonidos, mockups, temas de arranque de Limine y Plymouth, capturas de `docs/`) se
publica bajo **Creative Commons Atribución-CompartirIgual 4.0** ([`LICENCIA-ARTE.txt`](LICENCIA-ARTE.txt)). Puedes
reutilizarlo citando «OcarinaShell · Ayoub» y compartiendo tus obras derivadas con la misma licencia.

## 3. El nombre y el logo

El nombre **OcarinaShell / オカリナシェル** y el **logo de la ocarina** identifican el proyecto original de Ayoub y no
entran en las licencias anteriores. Puedes usarlos para hablar del proyecto o enlazarlo. Si publicas un fork, ponle
otro nombre y otro logo, para que nadie lo confunda con el original.

## 4. Sin garantía

OcarinaShell se ofrece **tal cual**, sin ninguna garantía (secciones 15 y 16 de la GPL). Toca partes delicadas del
sistema: compositor, arranque, bloqueo, actualizaciones y firmware. Por eso hace un snapshot antes de cada cambio
importante y trae un modo seguro y un rescate ([`05-RESCATE.md`](05-RESCATE.md)). Aun así, lo usas bajo tu propia
responsabilidad. Haz copias de lo que te importe.

## 5. Privacidad

- **Nada de telemetría.** OcarinaShell no recoge, no envía y no vende datos de uso.
- **蛇 Snake es local.** Los modelos de lenguaje y de voz se ejecutan en tu equipo. El audio del micrófono solo existe en
  RAM mientras se transcribe y se borra al instante.
- **Conexiones de red, solo las necesarias:**
  - el tiempo (Open-Meteo);
  - las actualizaciones de paquetes y de firmware (repositorios oficiales, AUR y LVFS);
  - las noticias que lee 守 Mamori (Arch Linux, CachyOS y GitHub, con lista blanca en `snake/sources.json`);
  - la descarga de modelos (Hugging Face, con sha256 comprobado);
  - Wallhaven, solo si activas la pestaña Explorar.
- **Claude es opcional.** Si eliges Claude como IA de Mamori, el contexto de mantenimiento (versiones, registros y
  diffs, nunca tus ficheros personales) se envía a Anthropic según sus condiciones. Por defecto se usa Snake (local).

## 6. Software de terceros

OcarinaShell se apoya en software de terceros con sus propias licencias, que se respetan y no se redistribuyen aquí:
- niri (GPL-3.0), Quickshell (LGPL-3.0), Qt (LGPL-3.0) y CachyOS/Arch;
- las tipografías (SIL OFL 1.1) y Material Symbols (Apache 2.0);
- whisper.cpp y llama.cpp (MIT), y los modelos con su licencia indicada en `snake/models.json`;
- lsfg-vk (CC BY-NC-ND) y Lossless Scaling, que debes haber comprado tú.

Los datos 七十二候 y 伝統色 son de dominio público; el tiempo, de Open-Meteo (CC BY 4.0).
