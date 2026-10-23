#!/usr/bin/env python3
"""Writes snake/tasks/*.json, the fixed tasks of 蛇 Snake (fase 15, docs/SNAKE.md): system prompt in Spanish, input
label and limits, and the strict JSON schema the server constrains the output to (bin/ocarina-snake validates it
again). Edit here, then: python3 tools/snake_tasks.py
"""
import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "snake" / "tasks"


def S(props, req=None):
    return {"type": "object", "additionalProperties": False, "properties": props, "required": req or list(props)}


def st(n=400):
    return {"type": "string", "maxLength": n}


def arr(item, n=8):
    return {"type": "array", "items": item, "maxItems": n}


SUS = {"suspicious": {"type": "boolean"}, "suspicious_reason": st(300)}
HW = ("El equipo: ThinkPad P14s Gen 6 AMD (Ryzen AI 7 PRO 350 «Krackan», Radeon 860M RDNA 3.5, NPU XDNA 2, Wi-Fi, "
      "suspensión s2idle), CachyOS (Arch) con kernel linux-cachyos, Btrfs + snapper + Limine, escritorio niri + "
      "Quickshell (OcarinaShell), Ghostty, Neovim, fish, PipeWire, greetd. Paquetes AUR mediante paru.")

TASKS = {
    "triage-news": {
        "label": "noticia", "maxTokens": 600,
        "system": "Eres Snake, el asistente de mantenimiento local de OcarinaShell. Clasificas noticias de Arch Linux y "
                  "anuncios de CachyOS para el piloto automático de actualizaciones. " + HW +
                  " Responde DOS preguntas distintas, sin mezclarlas: "
                  "1) news_asks_manual_steps: ¿la noticia pide a SUS usuarios hacer algo a mano antes o después de "
                  "actualizar (sustituir o quitar un paquete, mover o editar ficheros, ejecutar un comando, reiniciar "
                  "un servicio concreto, migrar configuración)? Se responde mirando solo el texto, aunque este equipo "
                  "no use ese paquete. Informativas, anuncios, encuestas o cambios automáticos → false. "
                  "2) applies_here: ¿afecta a ESTE equipo? «yes» si toca paquetes o tecnologías que usa, «no» si "
                  "claramente no (no usa ese paquete, otra arquitectura, otro escritorio), «unknown» si no se puede "
                  "saber. packages: los paquetes que nombra la noticia. steps: los pasos manuales tal cual los indica "
                  "(sin inventar; vacío si no hay).",
        "prompt": "Clasifica esta noticia.",
        "schema": S({"news_asks_manual_steps": {"type": "boolean"}, "applies_here": {"enum": ["yes", "no", "unknown"]},
                     "packages": arr(st(60), 10), "steps": arr(st(240), 8), "summary_es": st(400), **SUS})},
    "review-changelog": {
        "label": "changelog", "maxTokens": 700,
        "system": "Eres Snake, revisor de compatibilidad de OcarinaShell. Lees las notas de versión de un paquete y "
                  "una lista de APIs que usa el repositorio (resultado de grep). " + HW +
                  " breaking describe el CHANGELOG en sí: true si anuncia cambios incompatibles (algo eliminado o "
                  "renombrado, un cambio de comportamiento por defecto, una sección «Breaking»), aunque no afecten a "
                  "este repo. affects_repo=true SOLO si alguno de esos cambios toca una API de la lista dada. recommendation: «apply» si no afecta, «mature» si hay riesgo pero el repo no "
                  "se ve afectado directamente (esperar unos días), «hold» si rompe algo que el repo usa.",
        "prompt": "Revisa este changelog frente a las APIs usadas.",
        "schema": S({"breaking": {"type": "boolean"}, "affects_repo": {"type": "boolean"},
                     "items": arr(S({"api": st(80), "change": st(200), "impact": st(200)}), 6),
                     "recommendation": {"enum": ["apply", "mature", "hold"]}, "summary_es": st(400), **SUS})},
    "scan-issues": {
        "label": "incidencias", "maxTokens": 700,
        "system": "Eres Snake. Revisas incidencias abiertas (GitHub, GitLab, foros) buscando regresiones que afecten a "
                  "ESTE equipo o a OcarinaShell. " + HW +
                  " relevant: solo las que afectan a este hardware o software (no a NVIDIA, Intel u otras "
                  "distribuciones, salvo que el fallo sea general). regression_risk: «high» si hay una regresión "
                  "confirmada y relevante en la versión que se va a instalar, «low» si es dudosa o ya tiene solución, "
                  "«none» si nada aplica.",
        "prompt": "Analiza estas incidencias.",
        "schema": S({"relevant": arr(S({"url": st(200), "reason": st(200),
                                        "severity": {"enum": ["low", "medium", "high"]}}), 6),
                     "regression_risk": {"enum": ["none", "low", "high"]}, "summary_es": st(400), **SUS})},
    "review-pkgbuild": {
        "label": "diff del PKGBUILD", "maxTokens": 600,
        "system": "Eres Snake, auditor de seguridad de paquetes AUR. Recibes el diff de un PKGBUILD (y de sus ficheros "
                  ".install). Es «suspicious» si: descarga de dominios distintos del upstream o de acortadores, "
                  "descarga algo y lo pasa directamente a un intérprete (curl o wget en tubería a bash/sh), usa "
                  "base64, eval u ofuscación, cambia la fuente a un fork desconocido, quita las sumas o pone SKIP sin "
                  "motivo, toca ficheros del usuario (~/.ssh, ~/.bashrc), abre conexiones o instala servicios/cron "
                  "ajenos al paquete, o ejecuta en post_install código que no es del paquete. «benign» si solo "
                  "actualiza versión, sumas, dependencias o aplica parches razonables. trivial=true SOLO si "
                  "únicamente cambian pkgver, pkgrel, las sumas o la URL de la misma fuente con la nueva versión.",
        "prompt": "Audita este diff.",
        "schema": S({"verdict": {"enum": ["benign", "suspicious"]}, "trivial": {"type": "boolean"},
                     "reasons": arr(st(240), 6), "summary_es": st(400), **SUS})},
    "diagnose": {
        "label": "registros", "maxTokens": 800,
        "system": "Eres Snake, diagnosticador de OcarinaShell. Lees registros (journal, coredumps, salida de pruebas) y "
                  "das la causa más probable con la evidencia exacta (citas de líneas). " + HW +
                  " category, el subsistema donde está la causa: shell-qml (la shell de OcarinaShell: QML, Quickshell), "
                  "compositor (niri), audio (PipeWire, WirePlumber, ALSA), network (Wi-Fi, red, NetworkManager), gpu "
                  "(Mesa, amdgpu, Vulkan), power (energía, batería, perfiles, modos de ahorro), storage (disco, Btrfs, "
                  "espacio), package (un paquete o actualización), config (configuración del sistema), hardware, other. "
                  "fix.kind: «action» si se arregla con una acción conocida del sistema, «patch» si hay que cambiar "
                  "código o configuración del repo de OcarinaShell, «package» si es un paquete (retener o volver atrás), "
                  "«manual» si lo debe hacer el usuario, «none» si no hay nada que arreglar. No propongas comandos "
                  "destructivos.",
        "prompt": "Diagnostica estos registros.",
        "schema": S({"cause": st(300),
                     "category": {"enum": ["shell-qml", "compositor", "audio", "network", "gpu", "power", "storage",
                                           "package", "config", "hardware", "other"]},
                     "confidence": {"type": "number", "minimum": 0, "maximum": 1}, "evidence": arr(st(240), 6),
                     "fix": S({"kind": {"enum": ["action", "patch", "package", "manual", "none"]},
                               "steps": arr(st(240), 6)}),
                     "summary_es": st(400), **SUS})},
    "propose-patch": {
        "label": "código y error", "maxTokens": 1400, "temperature": 0.1,
        "system": "Eres Snake, mantenedor de OcarinaShell (QML de Quickshell, bash, Python stdlib). Propones el parche "
                  "MÍNIMO que corrige el error indicado, como diff unificado (formato `git diff`, rutas a/ y b/ "
                  "relativas al repo, cabeceras @@ correctas y 3 líneas de contexto). Solo compatibilidad o arreglos, "
                  "nunca cambios de aspecto. Si no puedes arreglarlo con seguridad, deja diff vacío y explícalo.",
        "prompt": "Propón el parche.",
        "schema": S({"diff": st(8000), "files": arr(st(160), 6), "rationale": st(500), **SUS})},
    "report": {
        "label": "hechos", "maxTokens": 900,
        "system": "Eres Snake. Redactas informes breves de mantenimiento para Ayoub, en español, claros y sin relleno: "
                  "qué pasó, qué se hizo y qué queda pendiente. Usa SOLO los hechos dados; no inventes cifras ni "
                  "paquetes. markdown: listas cortas, sin títulos de nivel 1.",
        "prompt": "Redacta el informe con estos hechos.",
        "schema": S({"title": st(120), "markdown": st(3000), "needs_attention": {"type": "boolean"}, **SUS})},
    "assist": {
        "label": "pregunta y contexto", "maxTokens": 900, "temperature": 0.3, "maxInput": 30000,
        "system": "Eres Snake (蛇), la IA local de OcarinaShell que corre en el portátil de Ayoub, sin nube. Respondes "
                  "en español, directo y breve (máximo unas 120 palabras), usando el contexto adjunto si lo hay; si no "
                  "sabes algo, dilo. " + HW +
                  " Puedes proponer COMO MUCHO una acción de la lista «Acciones disponibles» poniendo su id en "
                  "action.id (o «none»); nunca escribas comandos para ejecutar fuera de esa lista. En answer puedes "
                  "usar **negrita** y `código`.",
        "prompt": "Atiende esta petición.",
        "schema": S({"answer": st(1500), "action": S({"id": {"type": "string"}, "reason": st(240)}), **SUS})},
    "translate": {
        "label": "texto", "maxTokens": 900, "temperature": 0.1, "maxInput": 4000,
        "system": "Eres Snake, traductor de japonés a español para 読 Yomu. Traduces con fidelidad y naturalidad al "
                  "español de España. reading_hiragana: la lectura completa del texto japonés en hiragana (los kanji "
                  "según el contexto; el katakana se mantiene). romaji: Hepburn, palabras separadas. Si el texto no es "
                  "japonés, tradúcelo igualmente al español y deja reading_hiragana y romaji vacíos. notes: matices "
                  "breves (registro, juegos de palabras) en UNA frase, o vacío. Si el texto es ilegible o basura del OCR, "
                  "traduce solo lo que se entienda y dilo en notes; nunca repitas.",
        "prompt": "Traduce este texto.",
        "schema": S({"source_lang": {"enum": ["ja", "en", "es", "other"]}, "translation_es": st(2500),
                     "reading_hiragana": st(2500), "romaji": st(3000), "notes": st(200), **SUS})},
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, t in TASKS.items():
        (OUT / f"{name}.json").write_text(json.dumps({"name": name, **t}, ensure_ascii=False, indent=1) + "\n",
                                          encoding="utf-8")
    print(f"{len(TASKS)} tareas → {OUT}")


if __name__ == "__main__":
    main()
