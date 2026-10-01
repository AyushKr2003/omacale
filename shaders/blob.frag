#version 440
// Omacale frame + drawer background. A port of Caelestia's SDF "blob" shader
// (plugin/src/Caelestia/Blobs/shaders/blob.frag): the screen frame (an
// inverted rounded rect) and every open drawer are signed distance fields
// merged with a circular smooth-min, so drawers grow out of the frame with
// round fillets instead of hard joins.
//
// What Caelestia works out on the CPU (blobshape.cpp) comes in as uniforms:
// each rect's per-corner radii after corner fill (BlobFill.js) and its
// deformation matrix (BlobDeform.qml). One full-screen pass draws them all,
// where Caelestia draws one quad per shape.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;         // item size in px
    float smoothing;  // blend radius (Caelestia border.smoothing)
    float holeRadius; // inner frame rounding (border.rounding); < 0: no frame
    vec4 hole;        // inner hole: x, y, w, h
    vec4 color;
    vec4 r0;          // rects: x, y, w, h (w or h <= 0.5 disables)
    vec4 r1;
    vec4 r2;
    vec4 r3;
    vec4 r4;
    vec4 r5;
    vec4 r6;
    vec4 r7;
    vec4 r8;
    vec4 r9;
    vec4 c0;          // per-corner radii: tr, br, bl, tl
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 c5;
    vec4 c6;
    vec4 c7;
    vec4 c8;
    vec4 c9;
    vec4 d0;          // deformation: m00, m01, m11 (symmetric 2x2), 0
    vec4 d1;
    vec4 d2;
    vec4 d3;
    vec4 d4;
    vec4 d5;
    vec4 d6;
    vec4 d7;
    vec4 d8;
    vec4 d9;
    float excl56;     // > 0.5: r5 and r6 don't blend (Caelestia BlobRect.exclude)
    float excl18;     // > 0.5: r1 and r8 don't blend
};

float sdRoundedBox(vec2 p, vec2 c, vec2 hs, float r) {
    r = min(r, min(hs.x, hs.y));
    vec2 d = abs(p - c) - hs + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// Rounded box with per-corner radii r = (topRight, bottomRight, bottomLeft, topLeft).
float sdRoundedBox4(vec2 p, vec2 c, vec2 hs, vec4 r) {
    p -= c;
    r.xy = (p.x > 0.0) ? r.xy : r.wz;
    r.x = (p.y > 0.0) ? r.y : r.x;
    vec2 q = abs(p) - hs + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
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
    if (i == 5) return r5;
    if (i == 6) return r6;
    if (i == 7) return r7;
    if (i == 8) return r8;
    return r9;
}

vec4 radiiAt(int i) {
    if (i == 0) return c0;
    if (i == 1) return c1;
    if (i == 2) return c2;
    if (i == 3) return c3;
    if (i == 4) return c4;
    if (i == 5) return c5;
    if (i == 6) return c6;
    if (i == 7) return c7;
    if (i == 8) return c8;
    return c9;
}

// An unset deformation (all zero) is the identity.
vec3 deformAt(int i) {
    vec4 d = d9;
    if (i == 0) d = d0;
    else if (i == 1) d = d1;
    else if (i == 2) d = d2;
    else if (i == 3) d = d3;
    else if (i == 4) d = d4;
    else if (i == 5) d = d5;
    else if (i == 6) d = d6;
    else if (i == 7) d = d7;
    else if (i == 8) d = d8;
    if (d.x == 0.0 && d.z == 0.0) return vec3(1.0, 0.0, 1.0);
    return d.xyz;
}

bool excluded(int i, int j) {
    if (i == 5 && j == 6 && excl56 > 0.5) return true;
    if (i == 1 && j == 8 && excl18 > 0.5) return true;
    return false;
}

void main() {
    vec2 pixel = qt_TexCoord0 * res;
    float k = smoothing;
    bool framed = holeRadius >= 0.0;

    vec2 innerC = hole.xy + hole.zw * 0.5;
    vec2 innerH = hole.zw * 0.5;

    // Phase 1: each rect's distance, through its deformation. Caelestia
    // blob.frag main(), phase 1.
    float d[10];
    vec2 ctrs[10];
    vec2 halves[10]; // screen-space half extents of the deformed rect
    for (int i = 0; i < 10; i++) {
        vec4 r = rectAt(i);
        ctrs[i] = r.xy + r.zw * 0.5;
        halves[i] = r.zw * 0.5;
        if (r.z <= 0.5 || r.w <= 0.5) { d[i] = 1e10; continue; }

        vec3 m = deformAt(i);
        vec2 hs = r.zw * 0.5;
        float det = m.x * m.z - m.y * m.y;
        float invDet = abs(det) > 1e-6 ? 1.0 / det : 1.0;
        mat2 inv = mat2(m.z * invDet, -m.y * invDet, -m.y * invDet, m.x * invDet);
        float halfTr = 0.5 * (m.x + m.z);
        float halfDiff = 0.5 * (m.x - m.z);
        float minEig = halfTr - sqrt(halfDiff * halfDiff + m.y * m.y);
        vec2 sh = vec2(abs(m.x) * hs.x + abs(m.y) * hs.y, abs(m.y) * hs.x + abs(m.z) * hs.y);
        halves[i] = sh;

        vec2 c = ctrs[i];
        float di = sdRoundedBox4(c + inv * (pixel - c), c, hs, radiiAt(i));
        di *= max(minEig, 0.01);

        // Narrow the blend on the axis facing the frame while the rect is
        // still (nearly) inside the border, without lowering k (which would
        // sharpen it): a drawer that has only just come out is a tight tab,
        // not a wide swelling.
        if (framed) {
            float distY0 = (c.y + sh.y) - (innerC.y - innerH.y);
            float distY1 = (innerC.y + innerH.y) - (c.y - sh.y);
            float distX0 = (c.x + sh.x) - (innerC.x - innerH.x);
            float distX1 = (innerC.x + innerH.x) - (c.x - sh.x);
            float yProx = 1.0 - min(smoothstep(0.0, k, distY0), smoothstep(0.0, k, distY1));
            float xProx = 1.0 - min(smoothstep(0.0, k, distX0), smoothstep(0.0, k, distX1));

            vec2 q = abs(pixel - c) - sh;
            vec2 qp = max(q, vec2(0.0));
            float cornerLen = length(qp);
            float gradX = qp.x / max(cornerLen, 0.001);
            float gradY = qp.y / max(cornerLen, 0.001);
            float faceY = smoothstep(-4.0, 4.0, q.y - q.x);
            float faceX = 1.0 - faceY;
            float t = smoothstep(0.0, 2.0, cornerLen);
            float xWeight = mix(faceX, gradX, t);
            float yWeight = mix(faceY, gradY, t);
            di *= 1.0 + (xProx * xWeight + yProx * yWeight) * 3.0;
        }
        d[i] = di;
    }

    // Phase 2 and 3: hard min, then the pairwise smooth mins.
    float merged = 1e10;
    for (int i = 0; i < 10; i++) merged = min(merged, d[i]);
    for (int i = 0; i < 10; i++) {
        if (d[i] >= 1e9) continue;
        for (int j = i + 1; j < 10; j++) {
            if (d[j] >= 1e9 || max(d[i], d[j]) >= k) continue;
            if (excluded(i, j)) continue;
            merged = min(merged, smin(d[i], d[j], k));
        }
    }

    if (framed) {
        // The outer box reaches 50px past the screen so its own corners
        // never show; only the inner (hole) edge is visible.
        vec2 outerC = res * 0.5;
        vec2 outerH = res * 0.5 + vec2(50.0);
        float dOuter = sdBox(pixel, outerC, outerH) - 1.0;
        float dInner = sdRoundedBox(pixel, innerC, innerH, holeRadius);

        float innerTop = innerC.y - innerH.y, innerBot = innerC.y + innerH.y;
        float innerLeft = innerC.x - innerH.x, innerRight = innerC.x + innerH.x;
        float outerTop = outerC.y - outerH.y, outerBot = outerC.y + outerH.y;
        float outerLeft = outerC.x - outerH.x, outerRight = outerC.x + outerH.x;

        // Border "sinks": a drawer hidden in the frame pushes the inner wall
        // back so it leaves through a pocket rather than raising a bump.
        float sinkValue = 0.0;
        float preOff = k * (2.0 - sqrt(2.0)) * 0.5;
        for (int i = 0; i < 10; i++) {
            if (d[i] >= 1e9) continue;
            vec2 ctr = ctrs[i];
            vec2 sh = halves[i];
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

        // Omacale: between the launcher (r1) and the clipboard preview (r8)
        // the two frame fillets would overlap and meet in a point; in that
        // gap the fillet is half the gap wide, so the two arcs meet flat on
        // the frame as one U.
        float kFrameJoin = k;
        if (excl18 > 0.5 && d[1] < 1e9 && d[8] < 1e9 && pixel.y > innerC.y) {
            vec4 lo = r1.x <= r8.x ? r1 : r8;
            vec4 hi = r1.x <= r8.x ? r8 : r1;
            float gapL = lo.x + lo.z, gapR = hi.x;
            if (pixel.x > gapL && pixel.x < gapR) kFrameJoin = clamp((gapR - gapL) * 0.5, 1.0, k);
        }
        merged = smin(merged, dFrame, kFrameJoin);
    }

    float fw = max(fwidth(merged), 0.0001);
    float alpha = 1.0 - smoothstep(-fw, fw, merged);
    fragColor = vec4(color.rgb * color.a * alpha, color.a * alpha) * qt_Opacity;
}
