#!/usr/bin/env python3
"""Generate the QML logo component (QtQuick + QtQuick.Shapes, no layers/blur/shaders) from logo-geometry.json.

Every soft effect of the SVG (glow, contact shadow, specular, warm light, lacquer shine, rim light, seigaiha mask)
is reproduced with gradients. Elliptical gradients are exact: the body path is mapped into a space where the
gradient is a circle and the Shape is transformed back. The seigaiha arcs are pre-clipped (occlusion by the next
fans and by the rounded tile), so nothing needs a clip or a mask at runtime.

usage: python3 tools/qml_logo_gen.py [assets/logo/logo-geometry.json] [assets/logo/qml/OcarinaLogo.qml]
"""
import json
import math
import pathlib
import re
import sys

K = pathlib.Path(__file__).resolve().parent.parent


def n(v, nd=2):
    s = f"{v:.{nd}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "", "-") else s


# ----------------------------------------------------------------------------- path helpers (absolute M/L/C/Z)
TOK = re.compile(r"[MLCZ]|-?\d*\.?\d+(?:[eE]-?\d+)?")
ARITY = {"M": 1, "L": 1, "C": 3, "Z": 0}


def parse(d):
    toks, out, i = TOK.findall(d), [], 0
    while i < len(toks):
        c = toks[i]
        i += 1
        pts = []
        for _ in range(ARITY[c]):
            pts.append((float(toks[i]), float(toks[i + 1])))
            i += 2
        out.append((c, pts))
    return out


def fmt(cmds, nd=2):
    return " ".join(c + "".join(f" {n(x, nd)} {n(y, nd)}" for x, y in pts) for c, pts in cmds)


def mapped(cmds, fn):
    return [(c, [fn(x, y) for x, y in pts]) for c, pts in cmds]


def inverse_of(tx, ty, rot, sx, sy):
    """Inverse of p = T(tx,ty)·R(rot)·S(sx,sy)·q — i.e. QML transform [Scale, Rotation, Translate]."""
    a = math.radians(-rot)

    def fn(x, y):
        x, y = x - tx, y - ty
        return (x * math.cos(a) - y * math.sin(a)) / sx, (x * math.sin(a) + y * math.cos(a)) / sy
    return fn


def sample(cmds, per=48):
    """Points and tangents along a path made of M + C… + Z."""
    pts, cur = [], None
    for c, p in cmds:
        if c == "M":
            cur = p[0]
        elif c == "C":
            p0, (p1, p2, p3) = cur, p
            for k in range(per):
                t = k / per
                u = 1 - t
                x = u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0]
                y = u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]
                dx = 3 * u * u * (p1[0] - p0[0]) + 6 * u * t * (p2[0] - p1[0]) + 3 * t * t * (p3[0] - p2[0])
                dy = 3 * u * u * (p1[1] - p0[1]) + 6 * u * t * (p2[1] - p1[1]) + 3 * t * t * (p3[1] - p2[1])
                pts.append((x, y, dx, dy))
            cur = p3
    return pts


def inside(poly, x, y):
    c = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[i - 1]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def inset_polygon(cmds, d):
    """Polygon offset of the path by d towards the inside (rim light band = outer path minus this, odd-even)."""
    s = sample(cmds)
    poly = [(x, y) for x, y, _, _ in s]
    out = []
    for x, y, dx, dy in s:
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        if not inside(poly, x + nx * 0.5, y + ny * 0.5):
            nx, ny = -nx, -ny
        out.append((x + nx * d, y + ny * d))
    return "M " + " L ".join(f"{n(x, 1)} {n(y, 1)}" for x, y in out) + " Z"


def bbox(cmds):
    s = sample(cmds, 64)
    xs, ys = [p[0] for p in s], [p[1] for p in s]
    return min(xs), min(ys), max(xs), max(ys)


# ----------------------------------------------------------------------------- seigaiha 青海波 (pre-clipped arcs)
def seigaiha_path(R=34, y0=300, W=512, corner=114, ring=(1.0, 0.72, 0.44), lw=2.4, fade_top=307.2):
    fans, row, y = [], 0, y0
    while y < W + R:
        x = -(R if row % 2 else 0)
        while x < W + 2 * R:
            fans.append((x, y))
            x += 2 * R
        y += R / 2
        row += 1

    def in_tile(px, py, m=lw / 2):
        if px < m or py < m or px > W - m or py > W - m:
            return False
        cx, cy = min(max(px, corner), W - corner), min(max(py, corner), W - corner)
        return (px - cx) ** 2 + (py - cy) ** 2 <= (corner - m) ** 2

    bands = []
    for i, (fx, fy) in enumerate(fans):
        later = [(ox, oy) for ox, oy in fans[i + 1:] if abs(ox - fx) < 2.2 * R and abs(oy - fy) < 2.2 * R]
        for k in ring:
            r = R * k - 2

            def vis(a):
                px, py = fx + r * math.cos(a), fy + r * math.sin(a)
                if py < fade_top - lw or not in_tile(px, py):
                    return False
                return all((px - ox) ** 2 + (py - oy) ** 2 >= R * R for ox, oy in later)

            steps = 720
            angs = [-math.pi + math.pi * 2 * s / steps for s in range(steps + 1)]
            flags = [vis(a) for a in angs]
            s = 0
            while s <= steps:
                if not flags[s]:
                    s += 1
                    continue
                e = s
                while e + 1 <= steps and flags[e + 1]:
                    e += 1

                def edge(a_in, a_out):
                    for _ in range(24):
                        mid = (a_in + a_out) / 2
                        a_in, a_out = (mid, a_out) if vis(mid) else (a_in, mid)
                    return a_in
                a0 = edge(angs[s], angs[s - 1]) if s > 0 else angs[s]
                a1 = edge(angs[e], angs[e + 1]) if e < steps else angs[e]
                if (a1 - a0) * r > 0.6:
                    bands.append((fx, fy, r, a0, a1))
                s = e + 1

    ro_, ri_ = lw / 2, lw / 2
    out = []
    for fx, fy, r, a0, a1 in bands:
        ro, ri = r + ro_, r - ri_
        large = 1 if a1 - a0 > math.pi else 0
        P = lambda rr, a: f"{n(fx + rr * math.cos(a), 1)} {n(fy + rr * math.sin(a), 1)}"  # noqa: E731
        out.append(f"M {P(ro, a0)} A {n(ro, 1)} {n(ro, 1)} 0 {large} 1 {P(ro, a1)} L {P(ri, a1)} "
                   f"A {n(ri, 1)} {n(ri, 1)} 0 {large} 0 {P(ri, a0)} Z")
    return " ".join(out), len(bands)


# ----------------------------------------------------------------------------- QML
def argb(hex6, a):
    return f"#{round(a * 255):02x}{hex6.lstrip('#')}"


def main(geo_path, out_path):
    g = json.loads(pathlib.Path(geo_path).read_text())
    C = g["colors"]
    body = parse(g["body"])
    ip, mp, mb = g["iconPlacement"], g["markPlacement"], g["markViewBox"]
    rot, s = ip["rot"], ip["s"]
    assert (mp["rot"], mp["s"]) == (rot, s), "icon and mark must share rotation/scale"

    a = math.radians(rot)
    tdx = s * (g["tip"]["x"] * math.cos(a) - g["tip"]["y"] * math.sin(a))
    tdy = s * (g["tip"]["x"] * math.sin(a) + g["tip"]["y"] * math.cos(a))
    mark_ox, mark_oy = mp["cx"] - mb[0], mp["cy"] - mb[1]

    # overlays mapped into their gradient space (radius-100 circles), see inverse_of()
    warm = fmt(mapped(body, inverse_of(200, -10, 0, 1.2, 1.1)))
    spec = fmt(mapped(body, inverse_of(-92, -60, -6, 0.96, 0.26)))
    rim = g["body"] + " " + inset_polygon(body, 1.5)
    x0, y0, x1, y1 = bbox(body)
    # os-body intro origin = 50% / 60% of the group's fill-box (body + mouth + clipped overlays)
    ox, oy = 5.0, 13.4
    sei, nb = seigaiha_path()

    ang = math.radians(18)
    sh0, sh1 = -290, 300
    shine = dict(x1=sh0 * math.cos(ang), y1=sh0 * math.sin(ang), x2=sh1 * math.cos(ang), y2=sh1 * math.sin(ang))
    sh_w = 35 / (sh1 - sh0)
    sh_c0, sh_c1 = (-255 - sh0) / (sh1 - sh0), (265 - sh0) / (sh1 - sh0)

    seal = g["seal"]
    m, w = g["mouth"], g["window"]
    holes = g["holes"]
    waves = g["waves"]
    wa0, wa1 = g["waveAngles"]
    circle = "M -100 0 A 100 100 0 1 0 100 0 A 100 100 0 1 0 -100 0 Z"
    tile = "M 114 0 L 398 0 A 114 114 0 0 1 512 114 L 512 398 A 114 114 0 0 1 398 512 L 114 512 A 114 114 0 0 1 0 398 L 0 114 A 114 114 0 0 1 114 0 Z"
    seal_rect = "M 17 0 L 67 0 A 17 17 0 0 1 84 17 L 84 67 A 17 17 0 0 1 67 84 L 17 84 A 17 17 0 0 1 0 67 L 0 17 A 17 17 0 0 1 17 0 Z"

    hole_props = "\n".join(f"    property real _h{i}: 1; property real _p{i}: 1" for i in range(len(holes)))
    glow_props = "    " + "; ".join(f"property real _g{i}: 0" for i in range(len(holes)))
    press_ids = ", ".join(f"_pressAnim{i}" for i in range(len(holes)))
    press_anims = "\n".join(
        f"""    SequentialAnimation {{
        id: _pressAnim{i}
        NumberAnimation {{ target: root; property: "_g{i}"; to: 0.9; duration: 70; easing.type: Easing.OutCubic }}
        NumberAnimation {{ target: root; property: "_g{i}"; to: 0; duration: 330; easing.type: Easing.InCubic }}
    }}""" for i in range(len(holes)))
    reset_holes = " ".join(f"_h{i} = 0; _p{i} = 1;" for i in range(len(holes)))
    final_holes = " ".join(f"_h{i} = 1; _p{i} = 1;" for i in range(len(holes)))

    ez_in = "easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.9, 0.25, 1.15, 1, 1]"
    ez_draw = "easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0.7, 0.2, 1, 1, 1]"
    ez_stamp = "easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 1.5, 0.4, 1, 1, 1]"

    intro_holes = "\n".join(
        f"        SequentialAnimation {{ PauseAnimation {{ duration: {380 + 60 * i} }} "
        f"NumberAnimation {{ target: root; property: \"_h{i}\"; to: 1; duration: 420; {ez_in} }} }}"
        for i in range(len(holes)))
    intro_waves = "\n".join(
        f"""        SequentialAnimation {{
            PauseAnimation {{ duration: {d} }}
            ParallelAnimation {{
                NumberAnimation {{ target: root; property: "_w{i}"; to: {wa1 - wa0}; duration: 600; {ez_draw} }}
                NumberAnimation {{ target: root; property: "_w{i}o"; to: 1; duration: 120 }}
            }}
        }}""" for i, d in enumerate((780, 920)))
    # CSS: fingering every 4.2 s, first press 1.8 … 4.2 s after load; loops start when the intro ends (~1.67 s)
    press = "\n".join(
        f"""    SequentialAnimation {{   // fingering 指: hole {i}
        running: root._loop
        PauseAnimation {{ duration: {d} }}
        SequentialAnimation {{
            loops: Animation.Infinite
            NumberAnimation {{ target: root; property: "_p{i}"; to: 0.3; duration: 210; easing.type: Easing.InOutSine }}
            NumberAnimation {{ target: root; property: "_p{i}"; to: 1; duration: 210; easing.type: Easing.InOutSine }}
            PauseAnimation {{ duration: 3780 }}
        }}
        onRunningChanged: if (!running) root._p{i} = 1
    }}""" for i, d in enumerate((130, 580, 1030, 1480, 2080, 2530)))
    pulse = "\n".join(
        f"""    SequentialAnimation {{   // wave {i} breathing
        running: root._loop
        PauseAnimation {{ duration: {d} }}
        SequentialAnimation {{
            loops: Animation.Infinite
            NumberAnimation {{ target: root; property: "_w{i}s"; to: 1.07; duration: 1200; easing.type: Easing.InOutSine }}
            NumberAnimation {{ target: root; property: "_w{i}s"; to: 1; duration: 1200; easing.type: Easing.InOutSine }}
        }}
        onRunningChanged: if (!running) root._w{i}s = 1
    }}""" for i, d in enumerate((30, 330)))

    hole_items = []
    for i, h in enumerate(holes):
        r = h["r"]
        hx0, hy0 = -r * .74, r * .42
        hole_items.append(f"""                Item {{   // hole {i}
                    x: {n(h['x'])}; y: {n(h['y'])}
                    scale: root._h{i}; opacity: root._p{i}
                    Rectangle {{ x: {n(-r)}; y: {n(-r)}; width: {n(2 * r)}; height: {n(2 * r)}; radius: {n(r)}; color: root._holeColor; antialiasing: true }}
                    Rectangle {{   // lights up on press(i)
                        visible: root._g{i} > 0.01
                        x: {n(-r)}; y: {n(-r)}; width: {n(2 * r)}; height: {n(2 * r)}; radius: {n(r)}; antialiasing: true
                        color: root._mono ? root.monoColor : "{C['mouth0']}"; opacity: root._g{i}
                    }}
                    Shape {{
                        visible: root._gloss
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {{
                            fillColor: "transparent"; strokeColor: "#4dffffff"; strokeWidth: 2.6; capStyle: ShapePath.RoundCap
                            PathSvg {{ path: "M {n(hx0)} {n(hy0)} A {n(r)} {n(r)} 0 0 0 {n(-hx0)} {n(hy0)}" }}
                        }}
                    }}
                }}""")
    holes_qml = "\n".join(hole_items)

    wave_items = []
    for i, wv in enumerate(waves):
        wave_items.append(f"""            Shape {{   // wave {i}
                visible: root._w{i} > 0.2 && root._burst < 0.99
                opacity: {n(wv['opacity'])} * root._w{i}o * (1 - root._burst) * (1 - 0.45 * root._gray)
                preferredRendererType: Shape.CurveRenderer
                transform: Scale {{
                    origin.x: root._tipX; origin.y: root._tipY
                    xScale: root._w{i}s * (1 + 0.14 * root._kick) * (1 + {n(0.5 + 0.35 * i)} * root._burst); yScale: xScale
                }}
                ShapePath {{
                    strokeColor: "transparent"
                    fillColor: Qt.tint(root._mono ? root.monoColor : "{C['red']}", Qt.rgba(0.55, 0.53, 0.5, root._gray))
                    fillGradient: root._gloss && root._gray < 0.01 ? root._waveGrad{i} : null
                    PathSvg {{ path: root._band(root._tipX, root._tipY, {n(wv['r'])}, {n(wv['width'])}, {wa0}, {wa0} + root._w{i}) }}
                }}
            }}""")
    waves_qml = "\n".join(wave_items)

    wave_grads = []
    ca, sa = math.cos(math.radians(wa0)), math.sin(math.radians(wa0))
    for i, wv in enumerate(waves):
        r = wv["r"]
        wave_grads.append(f"""    property ShapeGradient _waveGrad{i}: LinearGradient {{   // objectBoundingBox (0,1)->(1,0) of the arc
        x1: root._tipX + {n(r * ca)}; y1: root._tipY
        x2: root._tipX + {n(r)}; y2: root._tipY + {n(r * sa)}
        GradientStop {{ position: 0; color: "{C['wave1']}" }}
        GradientStop {{ position: 1; color: "{C['wave0']}" }}
    }}""")
    wave_grads_qml = "\n".join(wave_grads)

    kx, ky = seal["kanjiOffset"]
    cur = seal["prompt"]["cursor"]

    qml = f"""// OcarinaLogo.qml — OcarinaShell logo (紅白, red on white) in pure QtQuick + QtQuick.Shapes.
// GENERATED by tools/qml_logo_gen.py from assets/logo/logo-geometry.json — do not edit by hand.
//
// No layers, no blur, no ShaderEffect: glow, contact shadow, specular, lacquer shine, rim light and the seigaiha
// fade are gradients (exactly like the SVGs). Static when animated:false; loops stop when invisible.
//   OcarinaLogo {{ width: 160; height: 160 }}                       // app tile: intro + calm loops
//   OcarinaLogo {{ variant: "mark"; style: "mono"; monoColor: Theme.fg; monoHoleColor: Theme.surface
//                 animated: false; height: Theme.barIcon; width: height * 430 / 270 }}   // bar: static
//   OcarinaLogo {{ animated: Motion.enabled; loops: !Power.saving }}  // obey Shinobi / reduced motion
// replay() restarts the intro (hover, unlock); press(i) / shake() / burst() are for the lock screen (Kagi).
// Intro ≈ 1.7 s; loops: float 5.2 s, fingering 4.2 s,
// waves 2.4 s, lacquer shine 6.5 s, hanko flip ❯_ ⇄ 殻 every ~4.5 s, cursor blink 1.1 s.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Item {{
    id: root

    property string variant: "icon"          // "icon" (512 tile) | "mark" (ocarina + waves, transparent)
    property string style: "gloss"           // "gloss" | "flat" | "mono"
    property string seal: "flip"             // icon only: "prompt" (❯_) | "kanji" (殻) | "flip" | "none"
    property bool pattern: true              // icon only: seigaiha 青海波 on the tile
    property bool animated: true             // false = final pose, no timers at all (bind to Motion.enabled)
    property bool loops: true                // false = intro only, then still
    property color monoColor: "{C['red']}"
    property color monoHoleColor: "#121216"  // mono: what shows through holes/window/seal glyphs (= background)
    property color paperColor: "{C['paper0']}"     // mono: tile colour

    signal introFinished()

    // Kagi (lock screen): press(i) on every key, shake() on a wrong password, burst() on success.
    function press(i) {{
        if (!root.animated)
            return;
        [{press_ids}][((i % 6) + 6) % 6].restart();
        _kickAnim.restart();
    }}
    function shake() {{
        if (root.animated)
            _shakeAnim.restart();
    }}
    function burst() {{
        if (root.animated)
            _burstAnim.restart();
    }}

    function replay() {{
        if (intro.running)
            intro.stop();
        root._reset();
        if (root.animated)
            intro.start();
        else
            root._final();
    }}

    implicitWidth: _icon ? 128 : 96
    implicitHeight: _icon ? 128 : Math.round(96 * _boxH / _boxW)
    Accessible.role: Accessible.Graphic
    Accessible.name: "OcarinaShell"

    // ------------------------------------------------------------------ internals
    readonly property bool _icon: variant !== "mark"
    readonly property bool _gloss: style === "gloss"
    readonly property bool _flat: style === "flat"
    readonly property bool _mono: style === "mono"
    readonly property bool _run: animated && visible && width > 0 && height > 0
    readonly property bool _loop: _run && loops && _introDone
    readonly property real _boxW: _icon ? 512 : {mb[2]}
    readonly property real _boxH: _icon ? 512 : {mb[3]}
    readonly property real _k: Math.min(width / _boxW, height / _boxH)
    readonly property real _ocX: _icon ? {n(ip['cx'])} : {n(mark_ox)}
    readonly property real _ocY: _icon ? {n(ip['cy'])} : {n(mark_oy)}
    readonly property real _tipX: _ocX + {n(tdx)}
    readonly property real _tipY: _ocY + {n(tdy)}
    readonly property color _holeColor: _mono ? monoHoleColor : (_flat ? "{C['paper0']}" : "{C['hole']}")
    readonly property color _sealInk: _mono ? monoHoleColor : "#ffffff"
    readonly property real _shineC: {n(sh_c0, 4)} + Math.max(0, _shine) * {n(sh_c1 - sh_c0, 4)}
    property bool _introDone: false

    // animated state (initial values = final pose)
    property real _bodyO: 1; property real _bodyS: 1; property real _bodyY: 0
{hole_props}
    property real _w0: {wa1 - wa0}; property real _w1: {wa1 - wa0}; property real _w0o: 1; property real _w1o: 1
    property real _w0s: 1; property real _w1s: 1
    property real _floatY: 0
    property real _shine: -1                 // lacquer shine sweep 0..1, < 0 = hidden
    property real _sealO: 1; property real _sealS: 1; property real _sealR: 0
    property real _flip: 1
    property real _kick: 0; property real _shakeX: 0; property real _gray: 0; property real _burst: 0
{glow_props}
    property bool _kanji: seal === "kanji"
    property bool _cursor: true

    function _reset() {{
        _introDone = false;
        _bodyO = 0; _bodyS = 0.86; _bodyY = 16;
        {reset_holes}
        _w0 = 0; _w1 = 0; _w0o = 0; _w1o = 0; _w0s = 1; _w1s = 1;
        _sealO = 0; _sealS = 1.7; _sealR = -16;
        _floatY = 0; _shine = -1; _flip = 1; _kanji = seal === "kanji"; _cursor = true;
    }}
    function _final() {{
        _bodyO = 1; _bodyS = 1; _bodyY = 0;
        {final_holes}
        _w0 = {wa1 - wa0}; _w1 = {wa1 - wa0}; _w0o = 1; _w1o = 1;
        _sealO = 1; _sealS = 1; _sealR = 0;
        if (!_introDone) {{
            _introDone = true;
            root.introFinished();
        }}
    }}
    // filled annular sector with round caps = a stroked arc that can take a gradient (angles in degrees, clockwise)
    function _band(cx, cy, r, w, a0, a1) {{
        const ro = r + w / 2, ri = r - w / 2, hw = w / 2, k = Math.PI / 180;
        const c0 = Math.cos(a0 * k), s0 = Math.sin(a0 * k), c1 = Math.cos(a1 * k), s1 = Math.sin(a1 * k);
        const lg = a1 - a0 > 180 ? 1 : 0;
        return "M " + (cx + ro * c0) + " " + (cy + ro * s0)
            + " A " + ro + " " + ro + " 0 " + lg + " 1 " + (cx + ro * c1) + " " + (cy + ro * s1)
            + " A " + hw + " " + hw + " 0 0 1 " + (cx + ri * c1) + " " + (cy + ri * s1)
            + " A " + ri + " " + ri + " 0 " + lg + " 0 " + (cx + ri * c0) + " " + (cy + ri * s0)
            + " A " + hw + " " + hw + " 0 0 1 " + (cx + ro * c0) + " " + (cy + ro * s0) + " Z";
    }}

    Component.onCompleted: animated ? replay() : _final()
    onAnimatedChanged: if (!animated && intro.running) intro.stop()
    onVisibleChanged: if (!visible && intro.running) intro.stop()
    onSealChanged: {{ _flip = 1; _kanji = seal === "kanji"; }}

    // ------------------------------------------------------------------ gradients
    property Gradient _mouthGrad: Gradient {{
        GradientStop {{ position: 0; color: "{C['mouth0']}" }}
        GradientStop {{ position: 1; color: "{C['mouth1']}" }}
    }}
    property ShapeGradient _bodyGrad: LinearGradient {{
        x1: -185; y1: -95; x2: 175; y2: 95
        GradientStop {{ position: 0; color: "{C['body0']}" }}
        GradientStop {{ position: 0.45; color: "{C['body1']}" }}
        GradientStop {{ position: 1; color: "{C['body2']}" }}
    }}
    property ShapeGradient _shineGrad: LinearGradient {{
        x1: {n(shine['x1'])}; y1: {n(shine['y1'])}; x2: {n(shine['x2'])}; y2: {n(shine['y2'])}
        GradientStop {{ position: Math.min(1, Math.max(0, root._shineC - {n(sh_w, 4)})); color: "#00ffffff" }}
        GradientStop {{ position: Math.min(1, Math.max(0, root._shineC)); color: "#52ffffff" }}
        GradientStop {{ position: Math.min(1, Math.max(0, root._shineC + {n(sh_w, 4)})); color: "#00ffffff" }}
    }}
{wave_grads_qml}

    // ------------------------------------------------------------------ intro (≈ 1.7 s)
    ParallelAnimation {{
        id: intro
        onStopped: root._final()
        NumberAnimation {{ target: root; property: "_bodyO"; to: 1; duration: 750; {ez_in} }}
        NumberAnimation {{ target: root; property: "_bodyS"; to: 1; duration: 750; {ez_in} }}
        NumberAnimation {{ target: root; property: "_bodyY"; to: 0; duration: 750; {ez_in} }}
{intro_holes}
{intro_waves}
        SequentialAnimation {{   // hanko stamp 判子
            PauseAnimation {{ duration: 1120 }}
            ParallelAnimation {{
                NumberAnimation {{ target: root; property: "_sealO"; to: 1; duration: 385; {ez_stamp} }}
                NumberAnimation {{ target: root; property: "_sealS"; to: 0.93; duration: 385; {ez_stamp} }}
                NumberAnimation {{ target: root; property: "_sealR"; to: 2; duration: 385; {ez_stamp} }}
            }}
            ParallelAnimation {{
                NumberAnimation {{ target: root; property: "_sealS"; to: 1; duration: 165; {ez_stamp} }}
                NumberAnimation {{ target: root; property: "_sealR"; to: 0; duration: 165; {ez_stamp} }}
            }}
        }}
    }}

    // ------------------------------------------------------------------ interaction (Kagi)
{press_anims}
    SequentialAnimation {{
        id: _kickAnim
        NumberAnimation {{ target: root; property: "_kick"; to: 1; duration: 90; easing.type: Easing.OutCubic }}
        NumberAnimation {{ target: root; property: "_kick"; to: 0; duration: 260; easing.type: Easing.InOutSine }}
    }}
    ParallelAnimation {{   // wrong password: tremble 300 ms, waves go grey for a moment
        id: _shakeAnim
        SequentialAnimation {{
            NumberAnimation {{ target: root; property: "_shakeX"; to: -12; duration: 40 }}
            NumberAnimation {{ target: root; property: "_shakeX"; to: 11; duration: 55 }}
            NumberAnimation {{ target: root; property: "_shakeX"; to: -8; duration: 55 }}
            NumberAnimation {{ target: root; property: "_shakeX"; to: 6; duration: 50 }}
            NumberAnimation {{ target: root; property: "_shakeX"; to: -3; duration: 50 }}
            NumberAnimation {{ target: root; property: "_shakeX"; to: 0; duration: 50 }}
        }}
        SequentialAnimation {{
            NumberAnimation {{ target: root; property: "_gray"; to: 1; duration: 120 }}
            PauseAnimation {{ duration: 700 }}
            NumberAnimation {{ target: root; property: "_gray"; to: 0; duration: 400; easing.type: Easing.InOutSine }}
        }}
    }}
    SequentialAnimation {{   // success: the waves burst outwards and fade
        id: _burstAnim
        NumberAnimation {{ target: root; property: "_burst"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }}
        ScriptAction {{ script: root._burst = 0 }}
    }}

    // ------------------------------------------------------------------ calm loops (only while visible)
    SequentialAnimation {{   // float 漂
        running: root._loop
        loops: Animation.Infinite
        NumberAnimation {{ target: root; property: "_floatY"; to: -7; duration: 2600; easing.type: Easing.InOutSine }}
        NumberAnimation {{ target: root; property: "_floatY"; to: 0; duration: 2600; easing.type: Easing.InOutSine }}
        onRunningChanged: if (!running) root._floatY = 0
    }}
{press}
{pulse}
    SequentialAnimation {{   // lacquer shine 艶
        running: root._loop && root._gloss
        PauseAnimation {{ duration: 530 }}
        SequentialAnimation {{
            loops: Animation.Infinite
            NumberAnimation {{ target: root; property: "_shine"; from: 0; to: 1; duration: 1430; easing.type: Easing.InOutSine }}
            ScriptAction {{ script: root._shine = -1 }}
            PauseAnimation {{ duration: 5070 }}
        }}
        onRunningChanged: if (!running) root._shine = -1
    }}
    SequentialAnimation {{   // hanko flip ❯_ ⇄ 殻
        running: root._loop && root._icon && root.seal === "flip"
        loops: Animation.Infinite
        PauseAnimation {{ duration: 4000 }}
        NumberAnimation {{ target: root; property: "_flip"; to: 0; duration: 270; easing.type: Easing.InSine }}
        ScriptAction {{ script: root._kanji = !root._kanji }}
        NumberAnimation {{ target: root; property: "_flip"; to: 1; duration: 270; easing.type: Easing.OutSine }}
        onRunningChanged: if (!running) {{ root._flip = 1; root._kanji = root.seal === "kanji"; }}
    }}
    Timer {{   // prompt cursor blink
        interval: 550; repeat: true
        running: root._loop && root._icon && root.seal !== "none" && !root._kanji
        onTriggered: root._cursor = !root._cursor
        onRunningChanged: if (!running) root._cursor = true
    }}

    // ------------------------------------------------------------------ drawing (model space, scaled to fit)
    Item {{
        id: box
        width: root._boxW; height: root._boxH
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        scale: root._k
        transformOrigin: Item.TopLeft

        Loader {{   // 512 tile: warm-white radial paper, seigaiha fade, hairline edge
            active: root._icon
            sourceComponent: Item {{
                width: 512; height: 512
                Shape {{
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {{
                        strokeColor: "transparent"
                        fillColor: root.paperColor
                        fillGradient: root._mono ? null : tileGrad
                        PathSvg {{ path: "{tile}" }}
                    }}
                    RadialGradient {{
                        id: tileGrad
                        centerX: 204.8; centerY: 153.6; centerRadius: 435.2; focalX: 204.8; focalY: 153.6
                        GradientStop {{ position: 0; color: "{C['paper0']}" }}
                        GradientStop {{ position: 0.62; color: "{C['paper0']}" }}
                        GradientStop {{ position: 1; color: "{C['paper1']}" }}
                    }}
                }}
                Loader {{
                    active: root.pattern && !root._mono
                    sourceComponent: Shape {{   // {nb} pre-clipped arcs, one path, one gradient
                        asynchronous: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {{
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {{
                                x1: 0; y1: 307.2; x2: 0; y2: 512
                                GradientStop {{ position: 0; color: "{argb(C['pattern'], 0)}" }}
                                GradientStop {{ position: 1; color: "{argb(C['pattern'], 0.075)}" }}
                            }}
                            PathSvg {{ path: "{sei}" }}
                        }}
                    }}
                }}
                Rectangle {{
                    anchors.fill: parent
                    radius: 114
                    color: "transparent"
                    border.width: 1.5
                    border.color: "#12000000"
                }}
            }}
        }}

        Item {{   // ocarina + waves float together
            width: root._boxW; height: root._boxH
            transform: Translate {{ x: root._shakeX; y: root._floatY }}

            Item {{
                id: oc
                x: root._ocX; y: root._ocY
                rotation: {n(rot)}; scale: {n(s)}
                transformOrigin: Item.TopLeft

                Shape {{   // glow (icon): circle r100 -> ellipse 250×150 at (0,30)
                    visible: root._icon && root._gloss
                    preferredRendererType: Shape.CurveRenderer
                    transform: [Scale {{ xScale: 2.5; yScale: 1.5 }}, Translate {{ y: 30 }}]
                    ShapePath {{
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {{
                            centerX: 0; centerY: 0; centerRadius: 100; focalX: 0; focalY: 0
                            GradientStop {{ position: 0; color: "{argb(C['body1'], 0.16)}" }}
                            GradientStop {{ position: 1; color: "{argb(C['body1'], 0)}" }}
                        }}
                        PathSvg {{ path: "{circle}" }}
                    }}
                }}
                Shape {{   // contact shadow: ellipse 178×21 at (0,124)
                    visible: root._gloss
                    preferredRendererType: Shape.CurveRenderer
                    transform: [Scale {{ xScale: 1.78; yScale: 0.21 }}, Translate {{ y: 124 }}]
                    ShapePath {{
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {{
                            centerX: 0; centerY: 0; centerRadius: 100; focalX: 0; focalY: 0
                            GradientStop {{ position: 0; color: "{argb(C['shadow'], 0.34)}" }}
                            GradientStop {{ position: 1; color: "{argb(C['shadow'], 0)}" }}
                        }}
                        PathSvg {{ path: "{circle}" }}
                    }}
                }}

                Item {{   // body group — intro: fade, rise and settle around 50%/60% of its box
                    opacity: root._bodyO
                    transform: [Scale {{ origin.x: {n(ox)}; origin.y: {n(oy)}; xScale: root._bodyS; yScale: root._bodyS }}, Translate {{ y: root._bodyY }}]

                    Rectangle {{   // mouthpiece 吹き口
                        x: {m['x']}; y: {m['y']}; width: {m['w']}; height: {m['h']}; radius: {m['rx']}
                        rotation: {m['rot']}
                        antialiasing: true
                        color: root._mono ? root.monoColor : "{C['mouth1']}"
                        gradient: root._gloss ? root._mouthGrad : undefined
                    }}
                    Shape {{   // body 胴
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {{
                            strokeColor: "transparent"
                            fillColor: root._mono ? root.monoColor : "{C['red']}"
                            fillGradient: root._gloss ? root._bodyGrad : null
                            PathSvg {{ path: "{g['body']}" }}
                        }}
                    }}
                    Item {{   // gloss overlays, all clipped to the body by construction
                        visible: root._gloss
                        Shape {{   // belly shade
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {{
                                strokeColor: "transparent"
                                fillGradient: LinearGradient {{
                                    x1: 0; y1: -5; x2: 0; y2: 100
                                    GradientStop {{ position: 0; color: "{argb(C['belly'], 0)}" }}
                                    GradientStop {{ position: 1; color: "{argb(C['belly'], 0.5)}" }}
                                }}
                                PathSvg {{ path: "{g['body']}" }}
                            }}
                        }}
                        Shape {{   // warm light near the tip: ellipse 120×110 at (200,-10)
                            preferredRendererType: Shape.CurveRenderer
                            transform: [Scale {{ xScale: 1.2; yScale: 1.1 }}, Translate {{ x: 200; y: -10 }}]
                            ShapePath {{
                                strokeColor: "transparent"
                                fillGradient: RadialGradient {{
                                    centerX: 0; centerY: 0; centerRadius: 100; focalX: 0; focalY: 0
                                    GradientStop {{ position: 0; color: "#73ffb08a" }}
                                    GradientStop {{ position: 1; color: "#00ffb08a" }}
                                }}
                                PathSvg {{ path: "{warm}" }}
                            }}
                        }}
                        Shape {{   // specular: ellipse 96×26 at (-92,-60), rotated -6°
                            preferredRendererType: Shape.CurveRenderer
                            transform: [Scale {{ xScale: 0.96; yScale: 0.26 }}, Rotation {{ angle: -6 }}, Translate {{ x: -92; y: -60 }}]
                            ShapePath {{
                                strokeColor: "transparent"
                                fillGradient: RadialGradient {{
                                    centerX: 0; centerY: 0; centerRadius: 100; focalX: 0; focalY: 0
                                    GradientStop {{ position: 0; color: "#b8ffffff" }}
                                    GradientStop {{ position: 0.6; color: "#33ffffff" }}
                                    GradientStop {{ position: 1; color: "#00ffffff" }}
                                }}
                                PathSvg {{ path: "{spec}" }}
                            }}
                        }}
                        Shape {{   // lacquer shine sweep
                            visible: root._shine >= 0
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {{
                                strokeColor: "transparent"
                                fillGradient: root._shineGrad
                                PathSvg {{ path: "{g['body']}" }}
                            }}
                        }}
                        Shape {{   // rim light: body minus a 1.5 inset (odd-even band)
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {{
                                strokeColor: "transparent"
                                fillRule: ShapePath.OddEvenFill
                                fillGradient: LinearGradient {{
                                    x1: -200; y1: -90; x2: 120; y2: -40
                                    GradientStop {{ position: 0; color: "#e6ffffff" }}
                                    GradientStop {{ position: 0.55; color: "#47ffffff" }}
                                    GradientStop {{ position: 1; color: "#00ffffff" }}
                                }}
                                PathSvg {{ path: "{rim}" }}
                            }}
                        }}
                    }}
                    Rectangle {{   // window 窓 (labium)
                        x: {w['x']}; y: {w['y']}; width: {w['w']}; height: {w['h']}; radius: {w['rx']}
                        rotation: {w['rot']}
                        antialiasing: true
                        color: root._holeColor
                    }}
{holes_qml}
                }}
            }}
{waves_qml}
        }}

        Loader {{   // hanko seal 判子 (icon)
            active: root._icon && root.seal !== "none"
            x: 386; y: 386
            sourceComponent: Item {{
                width: 84; height: 84
                scale: 86 / 84
                transformOrigin: Item.TopLeft
                Item {{
                    width: 84; height: 84
                    opacity: root._sealO
                    scale: root._sealS; rotation: root._sealR
                    transform: Scale {{ origin.x: 42; origin.y: 42; xScale: root._flip }}
                    Shape {{
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {{
                            strokeColor: "transparent"
                            fillColor: root.monoColor
                            fillGradient: root._mono ? null : sealGrad
                            PathSvg {{ path: "{seal_rect}" }}
                        }}
                        LinearGradient {{
                            id: sealGrad
                            x1: 0; y1: 0; x2: 84; y2: 84
                            GradientStop {{ position: 0; color: "{C['seal0']}" }}
                            GradientStop {{ position: 1; color: "{C['seal1']}" }}
                        }}
                    }}
                    Rectangle {{
                        x: 4.3; y: 4.3; width: 75.4; height: 75.4; radius: 13.7
                        color: "transparent"
                        border.width: 2.4
                        border.color: root._mono ? root.monoHoleColor : "#ebffffff"
                    }}
                    Shape {{   // ❯
                        visible: !root._kanji
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {{
                            fillColor: "transparent"
                            strokeColor: root._sealInk; strokeWidth: {seal['prompt']['stroke']}
                            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                            PathSvg {{ path: "{seal['prompt']['chevron']}" }}
                        }}
                    }}
                    Rectangle {{   // _ (blinking cursor)
                        visible: !root._kanji && root._cursor
                        x: {cur['x']}; y: {cur['y']}; width: {cur['w']}; height: {cur['h']}; radius: {n(cur['h'] / 2)}
                        color: root._sealInk
                    }}
                    Shape {{   // 殻 kara — shell
                        visible: root._kanji
                        x: {n(kx)}; y: {n(ky)}
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {{
                            strokeColor: "transparent"
                            fillColor: root._sealInk
                            PathSvg {{ path: "{seal['kanjiPath']}" }}
                        }}
                    }}
                }}
            }}
        }}
    }}
}}
"""
    out = pathlib.Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(qml)
    print(f"wrote {out} ({len(qml) // 1024} KB, {nb} seigaiha arcs, body bbox {n(x0)},{n(y0)} {n(x1)},{n(y1)})")


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0] if a else K / "assets/logo/logo-geometry.json", a[1] if len(a) > 1 else K / "assets/logo/qml/OcarinaLogo.qml")
