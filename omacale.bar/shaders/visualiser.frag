#version 440
// Omacale desktop visualiser. Caelestia paints these bars with QPainter in
// C++ (plugin/src/Caelestia/Components/visualiserbars.cpp: drawSide/paint);
// Omacale has no C++, and one fragment shader over a single quad is cheaper
// than a scene-graph item per bar: a frame only updates the uniforms below.
//
// The item is the bars' full reach (Caelestia's maxBarHeight, 40% of the
// inner screen height). Each side holds `count` bars over 40% of the width,
// mirrored so the lowest band sits at the outer edge; the fill is one
// vertical gradient, primary at the top of the reach to secondary at the base.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;         // item size in px
    float count;      // bars per side
    float spacing;    // gap after each bar, px
    float rounding;   // top corner radius, px
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 v0;         // bar heights 0..1, four per vec4 (up to 120 bars)
    vec4 v1;
    vec4 v2;
    vec4 v3;
    vec4 v4;
    vec4 v5;
    vec4 v6;
    vec4 v7;
    vec4 v8;
    vec4 v9;
    vec4 v10;
    vec4 v11;
    vec4 v12;
    vec4 v13;
    vec4 v14;
    vec4 v15;
    vec4 v16;
    vec4 v17;
    vec4 v18;
    vec4 v19;
    vec4 v20;
    vec4 v21;
    vec4 v22;
    vec4 v23;
    vec4 v24;
    vec4 v25;
    vec4 v26;
    vec4 v27;
    vec4 v28;
    vec4 v29;
};

void main() {
    vec2 p = qt_TexCoord0 * res;
    float n = max(count, 1.0);
    float slotW = res.x * 0.4 / n;
    float barW = slotW - spacing;

    bool right = p.x >= res.x * 0.6;
    if (barW <= 0.0 || (!right && p.x >= res.x * 0.4)) { fragColor = vec4(0.0); return; }

    float sx = right ? p.x - res.x * 0.6 : p.x;
    float i = min(floor(sx / slotW), n - 1.0);
    float x = sx - i * slotW;
    int idx = int(right ? i : n - 1.0 - i);

    vec4 vals[30] = vec4[](v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, v24, v25, v26, v27, v28, v29);
    float value = clamp(vals[idx / 4][idx % 4], 0.0, 1.0);
    float barH = value * res.y;
    if (barH <= 0.0) { fragColor = vec4(0.0); return; }

    // Distance to the bar: a box with only its top corners rounded.
    float r = min(rounding, min(barW * 0.5, barH));
    float top = res.y - barH;
    float d = max(max(-x, x - barW), top - p.y);
    if (p.y < top + r) {
        float cx = clamp(x, r, barW - r);
        vec2 q = vec2(x - cx, p.y - (top + r));
        if (x < r || x > barW - r) d = length(q) - r;
    }
    float alpha = clamp(0.5 - d, 0.0, 1.0);

    vec4 c = mix(primaryColor, secondaryColor, qt_TexCoord0.y);
    fragColor = vec4(c.rgb * c.a, c.a) * alpha * qt_Opacity;
}
