#version 440
// Liquid Glass surface for the island (components/LiquidGlass.qml).
//
// One signed-distance field holds every glass body: the island (or its two
// halves) and the two bubbles. They are joined with a smooth minimum, so a
// bubble pinches off the island like a droplet and two halves part with a
// thinning bridge. The fill is a translucent tint over the compositor's
// backdrop blur; the edge carries the "lensing" (a bright band that bends
// toward the edge) and a specular highlight that follows the light, which
// tracks the pointer.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // item size, logical px
    vec4 rectA;     // x, y, w, h of the island (or its left half)
    vec4 radA;      // corner radii: bottom-right, top-right, bottom-left, top-left
    vec4 rectB;     // right half (w = 0: none)
    vec4 radB;
    vec4 bub0;      // bubble: center x, center y, radius, 0
    vec4 bub1;
    float blend;    // smooth-union reach, px
    vec4 tint;      // glass tint, straight alpha
    vec2 light;     // unit vector toward the light (y down)
    float rim;      // edge highlight strength
    float energy;   // 0..1 flash of light on touch / morph
    vec4 ambL;      // the music's ambient colours, left and right
    vec4 ambR;
    float ambMix;   // 0: none, 1: full (follows the sound)
    vec4 pull;      // pointer: x, y, reach (px), sigma (px). The glass swells
                    // toward it like a drop drawn by a finger, never tearing
    float dark;     // light appearance: a faint dark outline, so clear glass
                    // still reads against light backgrounds
};

float sdRoundBox(vec2 p, vec2 b, vec4 r) {
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x  = (p.y > 0.0) ? r.x  : r.y;
    vec2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float boxAt(vec2 p, vec4 rc, vec4 rad) {
    if (rc.z <= 0.5 || rc.w <= 0.5) return 1e4;
    vec2 c = rc.xy + rc.zw * 0.5;
    vec4 r = min(rad, vec4(min(rc.z, rc.w) * 0.5));
    return sdRoundBox(p - c, rc.zw * 0.5, r);
}

float scene(vec2 p) {
    float d = boxAt(p, rectA, radA);
    d = smin(d, boxAt(p, rectB, radB), blend);
    if (bub0.z > 0.5) d = smin(d, length(p - bub0.xy) - bub0.z, blend);
    if (bub1.z > 0.5) d = smin(d, length(p - bub1.xy) - bub1.z, blend);
    // A smooth bump in the field: the body swells toward the pointer and
    // flows back when it leaves. Added to the distance, so it can only
    // stretch the glass, never split it.
    if (pull.z > 0.01) {
        vec2 q = p - pull.xy;
        d -= pull.z * exp(-dot(q, q) / (pull.w * pull.w));
    }
    return d;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = scene(p);
    float aa = max(fwidth(d), 0.0001);
    float cover = clamp(0.5 - d / aa, 0.0, 1.0);
    if (cover <= 0.0) { fragColor = vec4(0.0); return; }

    // Outward normal from the field.
    vec2 e = vec2(0.75, 0.0);
    vec2 n = vec2(scene(p + e.xy) - scene(p - e.xy), scene(p + e.yx) - scene(p - e.yx));
    float nl = length(n);
    n = nl > 0.0001 ? n / nl : vec2(0.0, -1.0);

    float inside = -d;                                   // px from the edge
    // Lensing: light gathered in a thin band along the edge, strongest where
    // the edge faces the light, with a softer counter-highlight opposite.
    float facing = dot(n, light);
    float band = 1.0 - smoothstep(0.0, 1.8, inside);
    float halo = 1.0 - smoothstep(0.0, 9.0, inside);
    float spec = pow(max(facing, 0.0), 3.0) + 0.45 * pow(max(-facing, 0.0), 3.0);
    float edge = band * (0.10 + 0.90 * spec) * rim;
    float glow = halo * (0.035 + 0.06 * max(facing, 0.0)) * rim;
    // A broad sheen across the top, as light falls on curved glass.
    float top = clamp(1.0 - inside / 40.0, 0.0, 1.0) * max(-n.y, 0.0) * 0.04;

    float lit = edge + glow + top + energy * (0.06 + 0.25 * band);
    // The music's colours live in the glass: a faint film across it (left
    // colour to right colour) and a stronger tint in the light it gathers
    // at the edges, so it reads as glass lit by the music.
    float span = clamp((p.x - rectA.x) / max(1.0, (rectB.z > 0.5 ? rectB.x + rectB.z : rectA.x + rectA.z) - rectA.x), 0.0, 1.0);
    vec3 amb = mix(ambL.rgb, ambR.rgb, smoothstep(0.15, 0.85, span));
    vec3 film = amb * ambMix * (0.10 + 0.22 * halo);
    vec3 light = mix(vec3(1.0), amb, ambMix * 0.7) * lit;
    vec3 col = tint.rgb * tint.a + film + light;
    float a = clamp(tint.a + lit * 0.9 + ambMix * 0.06, 0.0, 1.0);
    // Light glass: a hairline of shade just inside the edge (alpha only, so
    // it darkens whatever is behind), under the highlight.
    float outline = (1.0 - smoothstep(0.0, 1.2, inside)) * dark * 0.22;
    col *= 1.0 - outline * 0.4;
    a = clamp(a + outline, 0.0, 1.0);
    fragColor = vec4(col, a) * cover * qt_Opacity;
}
