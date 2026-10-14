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

float barValue(int idx) {
    // Load one uniform vec4. Indexing a temporary copy of all 30
    // uniforms per fragment saturated a Radeon 680M while this layer
    // was up and cava was running.
    int k = idx >> 2;
    vec4 v = v0;
    if (k == 1) v = v1;
    else if (k == 2) v = v2;
    else if (k == 3) v = v3;
    else if (k == 4) v = v4;
    else if (k == 5) v = v5;
    else if (k == 6) v = v6;
    else if (k == 7) v = v7;
    else if (k == 8) v = v8;
    else if (k == 9) v = v9;
    else if (k == 10) v = v10;
    else if (k == 11) v = v11;
    else if (k == 12) v = v12;
    else if (k == 13) v = v13;
    else if (k == 14) v = v14;
    else if (k == 15) v = v15;
    else if (k == 16) v = v16;
    else if (k == 17) v = v17;
    else if (k == 18) v = v18;
    else if (k == 19) v = v19;
    else if (k == 20) v = v20;
    else if (k == 21) v = v21;
    else if (k == 22) v = v22;
    else if (k == 23) v = v23;
    else if (k == 24) v = v24;
    else if (k == 25) v = v25;
    else if (k == 26) v = v26;
    else if (k == 27) v = v27;
    else if (k == 28) v = v28;
    else if (k == 29) v = v29;
    return clamp(v[idx & 3], 0.0, 1.0);
}

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

    float value = barValue(idx);
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
