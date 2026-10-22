#version 440
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ilyamiro and the Serpantinum contributors (https://github.com/ilyamiro/serpantinum).
// Glass lens ported from Serpantinum; the rest from Caelestia (GPL-3.0),
// Vitreus (MIT) and pleamar (BSD-3-Clause).
// See THIRD_PARTY.md.
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
//
// Omacale's liquid motion (core/Liquid.qml, Vitreus's necks) adds two
// things, both zero -- and so exactly Caelestia's output -- while it is off:
// a per-rect extra blend in the deformation's spare 4th component (the neck
// that joins a moving drawer to the frame and its neighbours), and up to
// four ellipses melted into everything (the ripples and the stray drop a
// drawer leaves on the edge it broke away from).
//
// Glass (core/Glass.qml, Vitreus's default glass: pleamar's shape.wgsl
// without its lens) draws the same shape as a translucent body that
// Hyprland blurs behind, smoked or milky, with light on its edge and its
// shadow only outside it. Off (glassA.x == 0), the output is the plain fill.
//
// Its edge is a bevel, lit by a gleam where its slope catches the light.
// With a backdrop (modules/drawers/GlassBackdrop.qml: the wallpaper and
// this screen's windows, rebuilt, with nothing of ours in it) the whole body
// is Serpantinum's liquid glass (src/assets/shaders/effects/liquid_glass.frag):
// a squircle bevel bending what is behind by Snell's law and pulling it into
// the rim, red and blue apart, lightly frosted and livened, tinted as a
// filter, the outside mirrored on the steep part, lit by a hairline, a sheen
// and a thin spectrum, swelling a little under the pointer.

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
    vec4 d0;          // deformation: m00, m01, m11 (symmetric 2x2), extra blend (liquid neck)
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
    vec4 b0;          // liquid bumps: centre x, y, radius x, y (r <= 0.3 disables)
    vec4 b1;
    vec4 b2;
    vec4 b3;
    vec4 bk;          // each bump's blend
    vec4 glassA;      // glass: on (> 0), body opacity, smoke, milk
    vec4 glassB;      // edge light, shadow alpha, shadow reach (px), light follows the pointer (> 0.5)
    vec2 pointer;     // the pointer, in px
    vec4 glassC;      // lens on (> 0.5), bevel (px), refraction (thickness), dispersion
    vec4 glassD;      // lens: frost (0 clear .. 1), gleam, reflection, dome (magnification)
    vec4 m0;          // each rect's motion energy (0..1): r0..r3
    vec4 m1;          // r4..r7
    vec4 m2;          // r8, r9
};

layout(binding = 1) uniform sampler2D backdrop;
layout(binding = 2) uniform sampler2D frosted;  // the same, blurred (GlassBackdrop)

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

float neckAt(int i) {
    if (i == 0) return d0.w;
    if (i == 1) return d1.w;
    if (i == 2) return d2.w;
    if (i == 3) return d3.w;
    if (i == 4) return d4.w;
    if (i == 5) return d5.w;
    if (i == 6) return d6.w;
    if (i == 7) return d7.w;
    if (i == 8) return d8.w;
    return d9.w;
}

float motionAt(int i) {
    if (i < 4) return i == 0 ? m0.x : i == 1 ? m0.y : i == 2 ? m0.z : m0.w;
    if (i < 8) return i == 4 ? m1.x : i == 5 ? m1.y : i == 6 ? m1.z : m1.w;
    return i == 8 ? m2.x : m2.y;
}

// An ellipse's distance, near enough at the edge for a blend.
float sdEllipse(vec2 p, vec2 c, vec2 r) {
    return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float bumpInto(float merged, vec2 pixel, vec4 b, float k) {
    if (b.z <= 0.3 || b.w <= 0.3) return merged;
    return smin(merged, sdEllipse(pixel, b.xy, b.zw), max(k, 0.5));
}

// Paint `col` at coverage `a` over premultiplied `c`.
vec4 over(vec4 c, vec3 col, float a) {
    return vec4(col * a + c.rgb * (1.0 - a), a + c.a * (1.0 - a));
}

// The bevel's slope from its edge (t = 0) to where the flat top begins
// (t = 1), for the gleam of the glass drawn without the lens.
float rimSlope(float t) {
    float s = 1.0 - t;
    return s * s * pow(max(1.0 - s * s * s, 1e-4), -2.0 / 3.0);
}
// pleamar's glass_tone: smoked glass takes what is seen through down, the
// brighter the more, keeping its colour; milky glass lifts it towards white,
// the darker the more; a frosted glass takes a little more milk.
vec3 glassTone(vec3 c, float smoke, float milk, float frost) {
    vec3 luma = vec3(0.2126, 0.7152, 0.0722);
    vec3 o = c * (1.0 - smoke * 0.58 * (0.35 + 0.65 * smoothstep(0.1, 0.85, dot(c, luma))));
    float lift = milk * min(mix(0.15, 0.25, frost) + 0.4 * (1.0 - smoothstep(0.3, 0.85, dot(o, luma))), 0.85);
    return mix(o, vec3(1.0), lift);
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
    float neck[10];
    vec2 ctrs[10];
    vec2 halves[10]; // screen-space half extents of the deformed rect
    for (int i = 0; i < 10; i++) {
        vec4 r = rectAt(i);
        ctrs[i] = r.xy + r.zw * 0.5;
        halves[i] = r.zw * 0.5;
        neck[i] = max(neckAt(i), 0.0);
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
            float kij = k + max(neck[i], neck[j]);
            if (d[j] >= 1e9 || max(d[i], d[j]) >= kij) continue;
            if (excluded(i, j)) continue;
            merged = min(merged, smin(d[i], d[j], kij));
        }
    }

    float dFrame = 1e10;
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
        dFrame = smaxSharpA(dOuter, -dInner, kFrame);

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
        // The liquid neck: a wider fillet between a moving drawer and the
        // frame. smin is monotone, so this only ever adds to the one above.
        for (int i = 0; i < 10; i++) {
            if (d[i] >= 1e9 || neck[i] <= 0.0) continue;
            merged = min(merged, smin(d[i], dFrame, kFrameJoin + neck[i]));
        }
    }

    merged = bumpInto(merged, pixel, b0, bk.x);
    merged = bumpInto(merged, pixel, b1, bk.y);
    merged = bumpInto(merged, pixel, b2, bk.z);
    merged = bumpInto(merged, pixel, b3, bk.w);

    float fw = max(fwidth(merged), 0.0001);
    float alpha = 1.0 - smoothstep(-fw, fw, merged);
    if (glassA.x <= 0.0) {
        fragColor = vec4(color.rgb * color.a * alpha, color.a * alpha) * qt_Opacity;
        return;
    }

    // Glass: pleamar shape.wgsl. Its light comes from the top left, or,
    // following the pointer, from the pointer as seen from the centre of the
    // drawer nearest this pixel (one direction per shape: from the pixel
    // itself it would fan out into a cone); the frame keeps the top-left
    // light, and the fillet between a drawer and the frame turns from one to
    // the other.
    // The sidebar and utilities, joined, are one slab: the 2px they overlap
    // by is no edge of the glass, so depth into it is measured from the
    // outline of the two together (the top one's top corners, the bottom
    // one's bottom ones).
    float body = merged;
    if (excl56 > 0.5 && d[5] < 1e9 && d[6] < 1e9) {
        bool sbTop = r6.y < r5.y;
        vec4 ra = sbTop ? r6 : r5;
        vec4 rb = sbTop ? r5 : r6;
        vec4 ca = sbTop ? c6 : c5;
        vec4 cb = sbTop ? c5 : c6;
        vec2 lo = vec2(min(ra.x, rb.x), ra.y);
        vec2 hi = vec2(max(ra.x + ra.z, rb.x + rb.z), rb.y + rb.w);
        float joint = sdRoundedBox4(pixel, (lo + hi) * 0.5, (hi - lo) * 0.5, vec4(ca.x, cb.y, cb.z, ca.w));
        if (merged < 0.0 && joint < 0.0) body = min(merged, joint);
    }
    vec2 g = vec2(dFdx(body), dFdy(body));
    vec2 outward = g / max(length(g), 1e-6);
    float inside = max(-body, 0.0);
    int near = -1;
    float dn = 1e10;
    for (int i = 0; i < 10; i++) if (d[i] < dn) { dn = d[i]; near = i; }
    // 1 on a drawer, 0 on the frame, turning over the fillet between them.
    float onDrawer = near >= 0 ? smoothstep(-k, k, dFrame - dn) : 0.0;
    vec2 toLight = normalize(vec2(-0.55, -0.83));
    if (glassB.w > 0.5 && near >= 0) {
        vec2 v = pointer - ctrs[near];
        vec2 toPointer = length(v) > 1e-3 ? normalize(v) : toLight;
        toLight = normalize(mix(toLight, toPointer, onDrawer) + vec2(1e-5));
    }
    // The edge that faces the light shines thin and strong, the opposite
    // one weaker (the light coming out), and the closer to the edge the
    // brighter: the glass seen edge-on.
    float rim = 1.0 - smoothstep(0.4, 3.0, inside);
    float facing = pow(max(dot(outward, toLight), 0.0), 1.6);
    float away = pow(max(-dot(outward, toLight), 0.0), 1.6);
    float fresnel = exp(-inside / 10.0);
    float shine = (rim * (0.85 * facing + 0.4 * away + 0.12) + 0.14 * fresnel) * glassB.x;

    // The bevel. A strip of frame narrower than it (the screen edge cuts
    // the frame, it isn't an edge of the glass) gets a bevel its own width.
    float edgeRoom = inside + min(min(pixel.x, pixel.y), min(res.x - pixel.x, res.y - pixel.y));
    float bevel = max(min(glassC.y, edgeRoom * 0.85), 1.0);
    float t = clamp(inside / bevel, 0.0, 1.0);
    // The gleam: the bevel as a surface, lit from the same side as the rim.
    // Where its tilt is half the light's, it mirrors the light: a soft line a
    // little inside the edge, which is what makes a slab read as thick. The
    // flat top's own share is taken off, so it stays on the bevel.
    vec3 lightDir = normalize(vec3(toLight * 0.75, 0.66));
    vec3 halfway = normalize(lightDir + vec3(0.0, 0.0, 1.0));
    vec3 tilt = normalize(vec3(outward * min(rimSlope(t) * 0.9, 30.0), 1.0));
    float gleam = max(pow(max(dot(tilt, halfway), 0.0), 36.0) - pow(halfway.z, 36.0), 0.0)
        * smoothstep(0.0, 1.5, inside) * glassD.y * glassB.x;

    // Its shadow, only round it: under glass a shadow would show through.
    float sh = glassB.y * pow(1.0 - smoothstep(0.0, max(glassB.z, 1.0), merged), 2.0) * (1.0 - alpha);
    vec4 c = vec4(0.0, 0.0, 0.0, sh);
    // Without a lens (or where the backdrop knows nothing), the body is its
    // colour, lit a little along the inside of its edge, as translucent as
    // it says, over what the compositor puts behind; smoke and milk are a
    // veil of black or white over that.
    vec3 tone = clamp(color.rgb + vec3(0.1 * glassB.x * smoothstep(-2.2, -0.4, merged)), 0.0, 1.0);
    c = over(c, tone, alpha * glassA.y);
    c = over(c, vec3(0.0), alpha * glassA.z * 0.35);
    c = over(c, vec3(1.0), alpha * glassA.w * 0.3);

    // The lens: pleamar's, the whole body. What is behind (the rebuilt
    // backdrop) seen through the glass: bent on the bevel by Snell's law,
    // red, green and blue apart; a little magnified towards a drawer's
    // middle (a dome); frosted by our own blur on the flat and sharper on
    // the bevel; toned (smoke, milk) on its own colours, livened, tinted,
    // and tinted more where it is bright or busy so what is written on the
    // glass always reads; the steep bevel mirroring the room round it.
    float lensW = 0.0;
    if (glassC.x > 0.5 && alpha > 0.0) {
        // Serpantinum's liquid glass (liquid_glass.frag), on our merged
        // shape. The bevel is a squircle, steep only in its outer quarter;
        // the ray through it is bent by Snell's law across the glass's
        // thickness, uncapped, and the edge is pulled inwards on top of that
        // (with a slight sideways ripple), so what is behind is drawn into
        // the rim and squeezed there, as a thick slab does.
        float bz = max(min(glassC.y * 1.45, edgeRoom * 0.85), 1.0);
        float u = clamp(inside / bz, 0.0, 1.0);
        float om = 1.0 - u;
        float om4 = om * om * om * om;
        float slope = min((om * om * om) / pow(max(1.0 - om4, 1e-3), 0.75), 7.0);

        // The pointer over a drawer: the light leans towards it, and the
        // glass swells a little under it.
        vec2 toCursor = pointer - pixel;
        float cd = length(toCursor);
        float hover = 0.0;
        vec2 hsN = near >= 0 ? halves[near] : res * 0.5;
        if (glassB.w > 0.5 && near >= 0) {
            float dp = sdRoundedBox4(pointer, ctrs[near], rectAt(near).zw * 0.5, radiiAt(near));
            hover = (1.0 - smoothstep(0.0, 24.0, dp)) * onDrawer;
        }
        float reach = max(40.0, min(hsN.x, hsN.y) * 1.2);
        float nearC = hover * exp(-cd * cd / (2.0 * reach * reach));
        float sigma = reach * 0.5;
        // A drawer on the move (Liquid while moving): thicker, bending and
        // splitting the light harder, magnifying more, for a moment.
        float motion = near >= 0 ? motionAt(near) * onDrawer : 0.0;
        float thick = bevel * 1.15 * glassC.z;
        float bulgeH = hover * exp(-cd * cd / (2.0 * sigma * sigma)) * 0.35 * thick;
        vec3 normal = normalize(vec3(outward * slope - bulgeH * toCursor / (sigma * sigma), 1.0));
        float th = thick * 1.35 * (1.0 + 0.12 * nearC + 0.64 * motion);
        vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / 1.5);
        vec2 dG = ray.xy / max(-ray.z, 0.2) * th;
        float edgeFall = om * om;
        float wobble = sin(dot(pixel, vec2(0.11, 0.09)) + inside * 0.35) * 0.5 + 0.5;
        dG += (-outward * edgeFall * bz * (0.294 + 0.11 * wobble)
            + vec2(-outward.y, outward.x) * edgeFall * bz * 0.092 * (wobble - 0.5)) * (1.0 + 0.644 * motion);
        // Red and blue bent a little further and a little less.
        float spread = glassC.w * 0.3 * (0.35 + 1.2 * edgeFall) * (1.0 + 2.2 * motion);

        // A small drawer magnifies its middle a little (Magnify); a big one
        // barely, as the lens of a large slab is flat.
        vec2 ps = pixel;
        if (near >= 0 && (glassD.w > 0.0 || motion > 0.0)) {
            vec2 rel = pixel - ctrs[near];
            vec2 hs = max(hsN, vec2(1.0));
            float zr = clamp(length(rel / hs), 0.0, 1.0);
            float lensK = 1.0 - 0.75 * smoothstep(180.0, 420.0, max(hs.x, hs.y));
            ps -= rel * (0.13 * glassD.w + 0.064 * motion) * (1.0 - zr * zr) * lensK * onDrawer;
        }

        // What is behind, frosted as lightly as Frost says (GlassBackdrop);
        // only one picture is sampled, as a mix of sharp and blurred is a
        // ghost, not a frost.
        vec4 sq = texture(frosted, clamp((ps + dG) / res, 0.0, 1.0));
        vec3 behind = sq.rgb / max(sq.a, 1e-3);
        float known = smoothstep(0.6, 0.98, sq.a);
        if (spread > 0.0 && dot(dG, dG) > 0.25) {
            vec4 sr = texture(frosted, clamp((ps + dG * (1.0 + spread)) / res, 0.0, 1.0));
            vec4 sb = texture(frosted, clamp((ps + dG * (1.0 - spread)) / res, 0.0, 1.0));
            if (sr.a > 0.05) behind.r = sr.r / sr.a;
            if (sb.a > 0.05) behind.b = sb.b / sb.a;
        }
        float rawGray = dot(behind, vec3(0.299, 0.587, 0.114));
        behind = mix(vec3(dot(behind, vec3(0.2126, 0.7152, 0.0722))), behind, 1.25);

        // The rim's shading: its lower edge and the bevel a touch darker,
        // what lies just outside the glass mirrored on the steep part
        // (Fresnel), and the side turned from the light in its own shadow.
        behind *= 1.0 - 0.06 * exp(-inside / 6.0) * clamp(outward.y, 0.0, 1.0);
        behind *= 1.0 - 0.025 * exp(-inside / (bz * 0.45));
        vec2 L = normalize(vec2(-0.55, -0.83));
        if (cd > 0.001) L = normalize(mix(L, toCursor / cd, hover * 0.4) + vec2(1e-5));
        float facing = dot(outward, L);
        float spec = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);
        float fres = pow(1.0 - normal.z, 1.5);
        if (fres > 0.001) {
            vec4 e = texture(frosted, clamp((pixel + outward * (inside + bz * 1.4)) / res, 0.0, 1.0));
            vec3 env = (e.a > 1e-3 ? e.rgb / e.a : behind) * 1.12 + 0.03;
            behind = mix(behind, env, clamp(fres * 0.55 * (0.4 + 0.6 * max(facing, 0.0)), 0.0, 0.6) * glassD.z);
        }
        behind *= 1.0 - 0.16 * exp(-inside / (bz * 0.55)) * max(-facing, 0.0);

        float frost = glassD.x;
        behind = glassTone(clamp(behind, 0.0, 1.0), glassA.z, glassA.w, frost);
        vec3 vivid = behind;
        // Busy (text, a window's lines, leaves): the fine detail frosting
        // takes away, the sharp backdrop against the frosted one, averaged
        // over a 4 x 4 grid across the whole drawer -- one value per drawer,
        // so the tint is even over it. Measured per pixel, any such measure
        // has edges of its own, and the tint drew them on the glass as lace.
        float detail = 0.0;
        if (near >= 0 && onDrawer > 0.0) {
            vec4 r = rectAt(near);
            float busy = 0.0;
            for (int gy = 0; gy < 4; gy++) {
                for (int gx = 0; gx < 4; gx++) {
                    vec2 uv = (r.xy + r.zw * (vec2(float(gx), float(gy)) + 0.5) / 4.0) / res;
                    vec4 a1 = texture(backdrop, uv);
                    vec4 a2 = texture(frosted, uv);
                    busy += abs(dot(a1.rgb - a2.rgb, vec3(0.299, 0.587, 0.114)));
                }
            }
            detail = smoothstep(0.015, 0.07, busy / 16.0) * onDrawer;
        }
        float bright = smoothstep(0.45, 0.9, rawGray);
        // The tint: pleamar's 22% at its default 36% body, following the
        // Opacity setting; more over bright or busy, the more so the clearer
        // the glass (a frosted one already softens what is behind).
        // The tint is a filter, Serpantinum's: what is behind multiplied
        // towards the surface colour, the more where it is bright.
        float tint = clamp(glassA.y * 0.6 * (0.7 + 0.6 * rawGray), 0.0, 1.0);
        vec3 glassCol = vivid * mix(vec3(1.0), tone, tint);
        glassCol = mix(glassCol, tone, max(bright * 0.45, detail * 0.6) * (1.0 - 0.45 * frost));

        // The light on it: a hairline right on the edge and a wider glow,
        // strong where they face the light; a broad sheen down the lit
        // bevel; a faint band where the bevel meets the flat; and, under it,
        // a thin spectrum where the glass splits the light (Colour fringes).
        float rimK = 0.45 * glassB.x * (1.0 + 0.5 * nearC);
        float hair = exp(-inside / 1.1);
        float wide = exp(-inside / 5.0);
        float edgeHi = (hair * (0.18 + 0.78 * spec) + wide * 0.10 * (0.30 + spec)) * rimK;
        float broad = exp(-inside / (bz * 0.45)) * pow(max(facing, 0.0), 2.0) * 0.2 * rimK;
        float mx = (inside - bz * 0.5) / (bz * 0.2 + 1.0);
        float men = exp(-mx * mx) * 0.07 * (0.35 + spec) * rimK;
        vec3 fringe = vec3(0.0);
        if (inside < bz * 2.5 && glassC.w > 0.0) {
            float fb = (inside - bz * 0.42) / (bz * 0.22 + 1.0);
            float phase = dot(outward, vec2(0.7, 0.45)) * 0.9 + inside / (bz * 1.6) + 0.15 * dot(pixel, vec2(0.004, 0.003));
            vec3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (phase + vec3(0.0, 0.33, 0.67)));
            fringe = (spectrum - 0.5) * exp(-fb * fb) * (0.04 + 0.08 * spec) * rimK * min(glassC.w / 0.35, 1.5) * (1.0 + 3.0 * motion);
        }
        glassCol += vec3(edgeHi + broad + men) + fringe;
        // A grain finer than a pixel's step keeps the gradients from banding.
        vec2 fc = gl_FragCoord.xy;
        vec3 h3 = fract(vec3(fc.xyx) * 0.1031);
        h3 += dot(h3, h3.yzx + 33.33);
        vec3 h4 = fract(vec3((fc * 1.7 + 17.0).xyx) * 0.1031);
        h4 += dot(h4, h4.yzx + 33.33);
        glassCol += vec3(fract((h3.x + h3.y) * h3.z) + fract((h4.x + h4.y) * h4.z) - 1.0) * 0.004;

        lensW = known;
        float w = known * alpha;
        c = c * (1.0 - w) + vec4(clamp(glassCol, 0.0, 1.0), 1.0) * w;
    }
    // The drawn glass's own light, where the lens doesn't draw.
    c = over(c, vec3(1.0), clamp(shine + gleam, 0.0, 1.0) * alpha * (1.0 - lensW));
    fragColor = c * qt_Opacity;
}
