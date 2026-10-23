#version 440
// 墨 Ink wipe — wallpaper transition (Kabegami). A blot of ink grows from `origin` with an irregular, noisy edge
// and reveals the new image over the old one. Qt 6 ShaderEffect conventions (std140 block `buf` with qt_Matrix and
// qt_Opacity). Compile (see scripts/build-shaders.sh):
//   qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o inkwipe.frag.qsb inkwipe.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1
    float aspect;       // width / height of the item
    float seed;         // random per transition, [0, 1)
    vec2 origin;        // normalised start point of the blot
    vec4 inkColor;      // faint tint on the front of the ink (premultiplied)
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - origin) * vec2(aspect, 1.0);
    float dist = length(p);
    // farthest corner from the origin, so progress 1 always covers the whole screen
    vec2 far = max(origin, vec2(1.0) - origin) * vec2(aspect, 1.0);
    float reach = length(far);

    // two octaves of noise bend the edge like ink soaking into washi
    vec2 q = uv * vec2(aspect, 1.0) * 6.0 + seed * 37.0;
    float n = noise(q) * 0.65 + noise(q * 3.1) * 0.35;
    float front = progress * (reach + 0.35) - 0.2 + (n - 0.5) * 0.28;
    float mask = 1.0 - smoothstep(front - 0.06, front, dist);

    vec4 a = texture(fromTex, uv);
    vec4 b = texture(toTex, uv);
    vec4 col = mix(a, b, mask);
    float rim = smoothstep(front - 0.10, front - 0.02, dist) * mask * (1.0 - progress);
    col.rgb = mix(col.rgb, inkColor.rgb, rim * inkColor.a);
    fragColor = col * qt_Opacity;
}
