.pragma library

// Optical centring of Material Symbols Rounded (FILL 1, wght 400, opsz 24). Each entry is [left, low]: how far the
// ink's bounding-box centre sits left of / below the 24-unit em centre, measured from the font with fontTools.
// OIcon { optical: true } moves the glyph back by that much (scaled to its size, snapped to device pixels) so a row
// of status icons shares one centre line. Glyphs not listed are already centred (volume_up, lan, notifications…).
var offCentre = {
    "wifi": [0, 0.5],
    "wifi_find": [0, 0.29],
    "wifi_off": [0, 0.71],
    "bluetooth": [0.65, 0],
    "volume_down": [0.25, 0],
    "volume_mute": [0.5, 0],
    "volume_off": [0.59, 0.7],
    "notifications_off": [0.69, 0.09]
};

function snap(units, size, dpr) {
    return Math.round(units * size / 24 * dpr) / dpr;
}

function shiftX(icon, size, dpr) {
    var o = offCentre[icon];
    return o ? snap(o[0], size, dpr) : 0;
}

function shiftY(icon, size, dpr) {
    var o = offCentre[icon];
    return o ? -snap(o[1], size, dpr) : 0;
}
