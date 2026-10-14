---
description: Bucle de pulido visual de un componente contra su mockup y el sistema de diseño. Uso — /pulir isla
argument-hint: "[barra|isla|engawa|toast|torii|kagi|dengen|despedida|settei|kabegami|terminal|nvim|oni|fune|snake|mamori|limine|plymouth]"
disable-model-invocation: true
---

Componente: $ARGUMENTS

1. Localiza su referencia: mockup en `assets/mockups/` (o `assets/boot/…/preview-*.png`) y su sección en
   `docs/02-DISENO.md`. Recorta la región del mockup con `magick` a `docs/evidencias/pulido/`.
2. Provoca el estado del componente (IPC/CLI; modo prueba para el bloqueo; QEMU para Limine), captura con
   `scripts/shot.sh` y recorta la misma región.
3. `scripts/compare.sh` y MIRA ambas imágenes. Lista diferencias concretas: posición (±px), tamaños, colores (muestrea
   píxeles), tipografía (familia, peso, tamaño, tracking, formas JP de los kanji), radios, opacidades, alineación.
4. Corrige las 3–5 más visibles, recarga y vuelve a capturar. Repite hasta 4 iteraciones o hasta que no queden
   diferencias relevantes.
5. Comprueba que no empeoraste el reposo (CPU de `qs`) ni rompiste Shinobi/Oni (Motion off). Commit `pulido: $ARGUMENTS`.
