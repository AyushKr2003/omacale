#version 440
// Omacale frame + drawer background. A port of Caelestia's SDF "blob" shader:
// the screen frame (an inverted rounded rect) and every open drawer are signed
// distance fields merged with a circular smooth-min, so drawers grow out of the
// frame with round fillets instead of hard joins.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;         // item size in px
    float smoothing;  // blend radius (Caelestia border.smoothing = 20)
    float holeRadius; // inner frame rounding (border.rounding = 25)
    float panelRadius;// drawer rounding (rounding.extraLarge = 28)
    vec4 hole;        // inner hole: x, y, w, h
    vec4 color;
    vec4 r0;          // drawer rects: x, y, w, h (w or h <= 0 disables)
    vec4 r1;
    vec4 r2;
    vec4 r3;
    vec4 r4;
    vec4 r5;
};

float sdRoundedBox(vec2 p, vec2 c, vec2 hs, float r) {
    r = min(r, min(hs.x, hs.y));
    vec2 d = abs(p - c) - hs + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

float sdBox(vec2 p, vec2 c, vec2 hs) {
    vec2 d = abs(p - c) - hs;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Circular smooth min: the fillet is a true circular arc of radius k.
float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

// Smooth max that keeps a's boundary sharp (the frame's outer screen edge).
float smaxSharpA(float a, float b, float k) {
    float sm = min(-k, max(a, b)) + length(max(vec2(a, b) + vec2(k), vec2(0.0)));
    return max(a, b) + (sm - max(a, b)) * smoothstep(0.0, k * 0.5, -a);
}

vec4 rectAt(int i) {
    if (i == 0) return r0;
    if (i == 1) return r1;
    if (i == 2) return r2;
    if (i == 3) return r3;
    if (i == 4) return r4;
    return r5;
}

void main() {
    vec2 pixel = qt_TexCoord0 * res;
    float k = smoothing;

    float d[6];
    for (int i = 0; i < 6; i++) {
        vec4 r = rectAt(i);
        if (r.z <= 0.5 || r.w <= 0.5) { d[i] = 1e10; continue; }
        d[i] = sdRoundedBox(pixel, r.xy + r.zw * 0.5, r.zw * 0.5, panelRadius);
    }

    float merged = 1e10;
    for (int i = 0; i < 6; i++) merged = min(merged, d[i]);
    for (int i = 0; i < 6; i++) {
        if (d[i] >= 1e9) continue;
        for (int j = i + 1; j < 6; j++) {
            if (d[j] >= 1e9 || max(d[i], d[j]) >= k) continue;
            merged = min(merged, smin(d[i], d[j], k));
        }
    }

    // Frame. The outer box reaches 50px past the screen so its own corners
    // never show; only the inner (hole) edge is visible.
    vec2 outerC = res * 0.5;
    vec2 outerH = res * 0.5 + vec2(50.0);
    vec2 innerC = hole.xy + hole.zw * 0.5;
    vec2 innerH = hole.zw * 0.5;
    float dOuter = sdBox(pixel, outerC, outerH) - 1.0;
    float dInner = sdRoundedBox(pixel, innerC, innerH, holeRadius);

    float innerTop = innerC.y - innerH.y, innerBot = innerC.y + innerH.y;
    float innerLeft = innerC.x - innerH.x, innerRight = innerC.x + innerH.x;
    float outerTop = outerC.y - outerH.y, outerBot = outerC.y + outerH.y;
    float outerLeft = outerC.x - outerH.x, outerRight = outerC.x + outerH.x;

    // Border "sinks": a drawer tucked into the frame pushes the inner wall
    // back so it emerges from a pocket rather than a bump.
    float sinkValue = 0.0;
    float preOff = k * (2.0 - sqrt(2.0)) * 0.5;
    for (int i = 0; i < 6; i++) {
        if (d[i] >= 1e9) continue;
        vec4 r = rectAt(i);
        vec2 ctr = r.xy + r.zw * 0.5;
        vec2 sh = r.zw * 0.5;
        float topPen = clamp(innerTop - (ctr.y + sh.y) - preOff, 0.0, innerTop - outerTop);
        float botPen = clamp((ctr.y - sh.y) - innerBot - preOff, 0.0, outerBot - innerBot);
        float leftPen = clamp(innerLeft - (ctr.x + sh.x) - preOff, 0.0, innerLeft - outerLeft);
        float rightPen = clamp((ctr.x - sh.x) - innerRight - preOff, 0.0, outerRight - innerRight);
        float hLat = max(abs(pixel.x - ctr.x) - sh.x, 0.0);
        float vLat = max(abs(pixel.y - ctr.y) - sh.y, 0.0);
        float topZone = 1.0 - smoothstep(innerTop, innerTop + k, pixel.y);
        float botZone = smoothstep(innerBot - k, innerBot, pixel.y);
        float leftZone = 1.0 - smoothstep(innerLeft, innerLeft + k, pixel.x);
        float rightZone = smoothstep(innerRight - k, innerRight, pixel.x);
        float s = k * 2.0;
        float sink = max(
            max(topPen * smoothstep(s, 0.0, hLat) * topZone, botPen * smoothstep(s, 0.0, hLat) * botZone),
            max(leftPen * smoothstep(s, 0.0, vLat) * leftZone, rightPen * smoothstep(s, 0.0, vLat) * rightZone));
        sinkValue = max(sinkValue, sink);
    }
    dInner -= sinkValue;

    float minThick = min(min(innerTop - outerTop, outerBot - innerBot), min(innerLeft - outerLeft, outerRight - innerRight));
    float kFrame = clamp(min(k, minThick - 1.0), 1.0, k);
    float dFrame = smaxSharpA(dOuter, -dInner, kFrame);

    merged = smin(merged, dFrame, k);

    float fw = max(fwidth(merged), 0.0001);
    float alpha = 1.0 - smoothstep(-fw, fw, merged);
    fragColor = vec4(color.rgb * color.a * alpha, color.a * alpha) * qt_Opacity;
}
