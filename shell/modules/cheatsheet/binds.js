// OcarinaShell · parse niri's binds.kdl for the cheat sheet (chuleta). Pure functions, no QML.
// parse(text, remap) → [{ group, keys: [string], title, combo, changed, off }] in file order, Mod+1…9 style runs
// collapsed into one row. remap = ~/.config/ocarinashell/binds.json's «remap» (bin/ocarina-binds): the keys shown are
// the effective ones; combo stays the original (what ocarina-binds is told), off = left without keys.
.pragma library

// group of a bind, from its action
function groupOf(action) {
    if (/^spawn "ocarina" "(audio|media|brightness)"/.test(action))
        return "media";
    if (/^spawn "ocarina"/.test(action))
        return "shell";
    if (/^spawn /.test(action))
        return "apps";
    if (/screenshot/.test(action))
        return "shots";
    if (/workspace/.test(action))
        return "workspaces";
    if (/^(quit|power-off-monitors|toggle-keyboard-shortcuts-inhibit|toggle-overview|show-hotkey-overlay)/.test(action))
        return "system";
    return "windows";
}

const GROUPS = {
    shell: { kanji: "殻", title: "Shell" },
    workspaces: { kanji: "間", title: "Espacios" },
    windows: { kanji: "窓", title: "Ventanas y columnas" },
    media: { kanji: "音", title: "Multimedia" },
    shots: { kanji: "撮", title: "Capturas" },
    apps: { kanji: "器", title: "Aplicaciones" },
    system: { kanji: "系", title: "Sistema" }
};
const ORDER = ["shell", "workspaces", "windows", "media", "shots", "apps", "system"];

// niri actions in words (only those without a hotkey-overlay-title need it)
const ACTIONS = {
    "focus-workspace": "Ir al espacio %",
    "move-column-to-workspace": "Llevar la columna al espacio %",
    "focus-workspace-up": "Espacio de arriba",
    "focus-workspace-down": "Espacio de abajo",
    "move-column-to-workspace-up": "Llevar la columna al espacio de arriba",
    "move-column-to-workspace-down": "Llevar la columna al espacio de abajo",
    "move-workspace-up": "Subir el espacio",
    "move-workspace-down": "Bajar el espacio",
    "focus-column-left": "Columna de la izquierda",
    "focus-column-right": "Columna de la derecha",
    "focus-column-first": "Primera columna",
    "focus-column-last": "Última columna",
    "focus-window-up": "Ventana de arriba",
    "focus-window-down": "Ventana de abajo",
    "move-column-left": "Mover la columna a la izquierda",
    "move-column-right": "Mover la columna a la derecha",
    "move-column-to-first": "Mover la columna al principio",
    "move-column-to-last": "Mover la columna al final",
    "move-window-up": "Subir la ventana",
    "move-window-down": "Bajar la ventana",
    "focus-monitor-left": "Pantalla de la izquierda",
    "focus-monitor-right": "Pantalla de la derecha",
    "focus-monitor-up": "Pantalla de arriba",
    "focus-monitor-down": "Pantalla de abajo",
    "move-column-to-monitor-left": "Llevar la columna a la pantalla izquierda",
    "move-column-to-monitor-right": "Llevar la columna a la pantalla derecha",
    "move-column-to-monitor-up": "Llevar la columna a la pantalla de arriba",
    "move-column-to-monitor-down": "Llevar la columna a la pantalla de abajo",
    "center-column": "Centrar la columna",
    "center-visible-columns": "Centrar las columnas visibles",
    "expand-column-to-available-width": "Ocupar el ancho libre",
    "reset-window-height": "Altura automática",
    "expel-window-from-column": "Sacar la ventana de la columna",
    "switch-preset-column-width": "Siguiente ancho predefinido",
    "switch-preset-window-height": "Siguiente altura predefinida",
    "set-window-height": "Altura de la ventana %",
    "set-column-width": "Ancho de la columna %",
    "toggle-window-floating": "Flotante / mosaico",
    "switch-focus-between-floating-and-tiling": "Foco entre flotantes y mosaico",
    "toggle-column-tabbed-display": "Columna en pestañas",
    "power-off-monitors": "Apagar las pantallas",
    "screenshot": "Captura de región",
    "screenshot-screen": "Captura de pantalla",
    "screenshot-window": "Captura de ventana",
    "toggle-keyboard-shortcuts-inhibit": "Atajos de la app / del escritorio",
    "toggle-overview": "Vista general",
    "show-hotkey-overlay": "Atajos de niri",
    "close-window": "Cerrar ventana",
    "maximize-column": "Maximizar columna",
    "fullscreen-window": "Pantalla completa"
};

// physical keys of a Spanish keyboard
const KEYS = {
    Mod: "Super", apostrophe: "'", masculine: "º", dead_grave: "`", dead_acute: "´", plus: "+", minus: "-",
    Comma: ",", Period: ".", Page_Down: "AvPág", Page_Up: "RePág", Print: "ImpPnt", Escape: "Esc", Delete: "Supr",
    Left: "←", Right: "→", Up: "↑", Down: "↓", Home: "Inicio", End: "Fin", Return: "↵",
    WheelScrollDown: "Rueda ↓", WheelScrollUp: "Rueda ↑", WheelScrollLeft: "Rueda ←", WheelScrollRight: "Rueda →",
    XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Silencio", XF86AudioMicMute: "Micro",
    XF86AudioPlay: "Play", XF86AudioPause: "Pausa", XF86AudioNext: "Siguiente", XF86AudioPrev: "Anterior",
    XF86MonBrightnessUp: "Brillo +", XF86MonBrightnessDown: "Brillo −", XF86Favorites: "★", XF86Launch1: "Fn F12",
    Super: "Super"
};

function keyName(k) {
    return KEYS[k] !== undefined ? KEYS[k] : k;
}

// the shell's own commands in words
const OCARINA = {
    "audio up": "Subir el volumen", "audio down": "Bajar el volumen", "audio mute": "Silenciar",
    "audio mic": "Silenciar el micrófono", "media toggle": "Reproducir / pausa", "media next": "Pista siguiente",
    "media prev": "Pista anterior", "media up": "Volumen del reproductor +", "media down": "Volumen del reproductor −",
    "brightness up": "Subir el brillo", "brightness down": "Bajar el brillo",
    "brightness up --all": "Subir el brillo de todas las pantallas",
    "brightness down --all": "Bajar el brillo de todas las pantallas", "engawa": "Centro de control"
};

function describe(action) {
    const m = /^([a-z-]+)\s*(.*?);?\s*$/.exec(action);
    if (!m)
        return action;
    const name = m[1], arg = m[2].replace(/"/g, "").replace(/;$/, "").trim();
    if (name === "spawn") {
        const parts = (action.match(/"([^"]*)"/g) || []).map(s => s.slice(1, -1));
        if (parts[0] === "ocarina")
            return OCARINA[parts.slice(1).join(" ")] || "ocarina " + parts.slice(1).join(" ");
        return parts.join(" ");
    }
    const t = ACTIONS[name];
    if (!t)
        return name.replace(/-/g, " ");
    return t.replace("%", arg).trim();
}

function parse(text, remap) {
    const re = remap || {};
    const out = [];
    for (const raw of (text || "").split("\n")) {
        const line = raw.trim();
        if (line === "" || line.startsWith("//") || line.startsWith("binds") || line === "}")
            continue;
        // Keys [props] { action; }
        const m = /^(\S+)\s*(.*?)\{\s*(.*?)\s*\}\s*(\/\/.*)?$/.exec(line);
        if (!m)
            continue;
        const combo = m[1], props = m[2], action = m[3].replace(/;\s*$/, "");
        const tm = /hotkey-overlay-title=(?:"((?:[^"\\]|\\.)*)"|(null))/.exec(props);
        if (tm && tm[2] === "null" && !/XF86Favorites/.test(combo))
            continue;
        // the overlay title, without the kanji in brackets (the row shows plain Spanish)
        const title = tm && tm[1] !== undefined ? tm[1].replace(/\s*\([^)]*[\u3000-\u9fff][^)]*\)\s*$/, "") : describe(action);
        const eff = re[combo] !== undefined ? re[combo] : combo;
        out.push({ group: groupOf(action), keys: eff === "" ? [] : eff.split("+").map(keyName), title: title,
                   action: action, combo: combo, changed: eff !== combo, off: eff === "" });
    }
    // collapse runs that differ only in a trailing digit 1…9 ("Mod+1 … Mod+9 · Ir al espacio 1…9")
    const merged = [];
    for (const b of out) {
        const prev = merged[merged.length - 1];
        const last = b.keys[b.keys.length - 1];
        if (prev && !b.changed && !prev.changed && /^[1-9]$/.test(last) && prev.run && prev.keys.slice(0, -1).join("+") === b.keys.slice(0, -1).join("+")
            && prev.actionBase === b.action.replace(/\d+\s*$/, "")) {
            prev.runEnd = last;
            prev.keys[prev.keys.length - 1] = prev.runStart + "…" + last;
            prev.title = prev.titleBase.replace("%", prev.runStart + "–" + last);
            continue;
        }
        if (/^[1-9]$/.test(last) && !b.changed) {
            const base = b.action.replace(/\d+\s*$/, "");
            const name = /^([a-z-]+)/.exec(b.action)[1];
            merged.push(Object.assign({}, b, { run: true, runStart: last, actionBase: base,
                                               titleBase: (ACTIONS[name] || b.title) }));
        } else {
            merged.push(b);
        }
    }
    // same group and title: one row with alternative keys ("Super+Ctrl+H / ←"). Mouse-wheel variants only show
    // when there is no keyboard one (this is a sheet of keys)
    const wheel = b => b.keys.some(k => k.startsWith("Rueda"));
    const rows = [];
    for (const b of merged) {
        const twin = b.changed ? null : rows.find(r => r.group === b.group && r.title === b.title && !r.changed);
        if (!twin) {
            rows.push(Object.assign({}, b, { alts: [] }));
            continue;
        }
        if (wheel(b) && !wheel(twin))
            continue;
        if (!wheel(b) && wheel(twin)) {
            twin.keys = b.keys;
            twin.alts = [];
            continue;
        }
        const head = twin.keys.slice(0, -1).join("+");
        twin.alts.push(head === b.keys.slice(0, -1).join("+") ? b.keys[b.keys.length - 1] : b.keys.join("+"));
    }
    return rows;
}

function groups() {
    return ORDER.map(id => ({ id: id, kanji: GROUPS[id].kanji, title: GROUPS[id].title }));
}
