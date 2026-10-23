// OcarinaShell · 墨 ink cursor — a short brush stroke from the old cursor to the new one that retracts into the
// cursor and fades in ~120 ms. Ghostty 1.3 custom-shader uniforms (`ghostty +show-config --default --docs`).
// Loaded only on AC power, outside 忍 Shinobi and with motion enabled: the shell writes
// ~/.local/state/ocarinashell/theme/ghostty-effects.conf. Ordinary typing (one-cell moves) draws nothing.

const float DURATION = 0.12;   // seconds until the stroke is gone
const float MIN_JUMP = 1.2;    // in cursor heights: shorter moves (typing) get no stroke
const float HEAD = 0.20;       // stroke radius at the cursor, in cursor heights
const float TAIL = 0.03;       // stroke radius at the tail

// distance from p to the segment a→b (x) and where along it the closest point lies, 0 at a … 1 at b (y)
vec2 segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 term = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = term;

    float t = iTime - iTimeCursorChange;
    if (iFocus == 0 || t < 0.0 || t >= DURATION)
        return;

    // xy is the left/top corner (y grows upwards): centre of each cursor cell
    vec2 cur = iCurrentCursor.xy + vec2(iCurrentCursor.z, -iCurrentCursor.w) * 0.5;
    vec2 prev = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    float cell = max(iCurrentCursor.w, 1.0);
    if (length(cur - prev) < cell * MIN_JUMP)
        return;

    float k = t / DURATION;                       // 0 → 1
    float ease = 1.0 - (1.0 - k) * (1.0 - k) * (1.0 - k);
    vec2 tail = mix(prev, cur, ease);             // the tail chases the cursor

    vec2 seg = segment(fragCoord, cur, tail);
    float d = seg.x;
    float h = seg.y;                              // 0 at the cursor, 1 at the tail
    float radius = cell * mix(HEAD, TAIL, h);
    float ink = 1.0 - smoothstep(radius - 1.0, radius + 1.0, d);
    float alpha = ink * (1.0 - k) * (1.0 - k) * mix(0.9, 0.35, h);

    // the cursor colour arrives in sRGB while the blend happens in linear light: decode it, or 紅 turns magenta
    vec3 ink_rgb = pow(iCurrentCursorColor.rgb, vec3(2.2));
    fragColor = vec4(mix(term.rgb, ink_rgb, alpha), term.a);
}
