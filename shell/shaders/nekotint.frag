#version 440
// ネコ Neon in the theme's accent (Hiroba's vibe cat, fase 17). tools/neko_gen.py renders each layer with its reds
// rebuilt from black (`base`) and the difference to white (`tint` = how much accent each pixel holds); rasterising is
// linear in those colours, so base + tint × accent gives back the original scene with #ff1f3d and the same scene in
// any other accent. The greys live in `base` only and never change. Textures are premultiplied, which keeps the sum
// right: both share the layer's alpha. Compile (scripts/build-shaders.sh):
//   qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o nekotint.frag.qsb nekotint.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;        // the neon colour (opaque)
};

layout(binding = 1) uniform sampler2D base;
layout(binding = 2) uniform sampler2D tint;

void main() {
    vec4 b = texture(base, qt_TexCoord0);
    vec4 t = texture(tint, qt_TexCoord0);
    fragColor = vec4(min(b.rgb + t.rgb * accent.rgb, vec3(b.a)), b.a) * qt_Opacity;
}
