// OcarinaShell · colour maths for 色 Iro: sRGB ↔ OKLab/OKLCH (Björn Ottosson's matrices) and the nearest
// traditional colour by Euclidean distance in OKLab (ΔE_OK, perceptual: < 0.02 is hard to tell apart).
.pragma library

function linear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

// r, g, b in 0…1 → [L, a, b]
function oklab(r, g, b) {
    const lr = linear(r), lg = linear(g), lb = linear(b);
    const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
    const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
    const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
}

function oklch(r, g, b) {
    const [L, A, B] = oklab(r, g, b);
    const C = Math.sqrt(A * A + B * B);
    let h = Math.atan2(B, A) * 180 / Math.PI;
    if (h < 0)
        h += 360;
    return [L, C, h];
}

function hexToRgb(hex) {
    const h = hex.replace("#", "");
    return [parseInt(h.slice(0, 2), 16) / 255, parseInt(h.slice(2, 4), 16) / 255, parseInt(h.slice(4, 6), 16) / 255];
}

function hex(r, g, b) {
    const p = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
    return "#" + p(r) + p(g) + p(b);
}

// every format Iro offers, as copyable strings
function formats(r, g, b) {
    const [L, C, h] = oklch(r, g, b);
    const n = v => Math.round(v * 255);
    return {
        hex: hex(r, g, b),
        rgb: "rgb(" + n(r) + " " + n(g) + " " + n(b) + ")",
        oklch: "oklch(" + (L * 100).toFixed(1) + "% " + C.toFixed(3) + " " + (C < 0.002 ? "0" : h.toFixed(1)) + ")"
    };
}

// palette: [{ hex, ... }] → { color, distance } of the closest one
function nearest(r, g, b, palette) {
    const p = oklab(r, g, b);
    let best = null, bestD = Infinity;
    for (const c of palette || []) {
        const q = oklab.apply(null, hexToRgb(c.hex));
        const d = Math.sqrt((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2);
        if (d < bestD) {
            bestD = d;
            best = c;
        }
    }
    return { color: best, distance: bestD };
}
