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
// Its edge is a bevel: lit by a gleam where its slope catches the light,
// and, with a backdrop (modules/drawers/GlassBackdrop.qml: the wallpaper and
// this screen's windows, rebuilt, with nothing of ours in it), bending what
// is behind as pleamar's lens does -- Snell's law through the bevel's
// profile, red, green and blue apart, the room round it mirrored on the
// steep part -- and handing over to Hyprland's own blur where it flattens.

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

// pleamar's lens (shape.wgsl), after True Glass for Omarchy and HyprGlass:
// the bevel's height from its edge (t = 0) to where the flat top begins
// (t = 1), (1 - (1 - t)^3)^(1/3), and its slope.
float rimHeight(float t) {
    float s = 1.0 - t;
    return pow(max(1.0 - s * s * s, 0.0), 1.0 / 3.0);
}
float rimSlope(float t) {
    float s = 1.0 - t;
    return s * s * pow(max(1.0 - s * s * s, 1e-4), -2.0 / 3.0);
}
// A colour's index (Cauchy, fitted at n = 1.5 to an Abbe number of
// 10 / dispersion).
float iorFor(float lambda2, float dispersion) {
    if (dispersion <= 0.0) return 1.5;
    float b = 0.5 / ((10.0 / dispersion) * 1.9105);
    return 1.5 - b / 0.34527 + b / lambda2;
}
float tanhApprox(float x) { return 1.0 - 2.0 / (exp(2.0 * x) + 1.0); }
// Where the ray seen here comes from: straight down into the bevel tilted
// `slope` towards `outward`, bent by Snell's law, across the glass's height
// z; eased into `cap` (half the bevel) so a corner never folds over.
vec2 refractOffset(vec2 outward, float slope, float ior, float z, float cap) {
    vec3 n = normalize(vec3(outward * slope, 1.0));
    vec3 t = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / ior);
    if (t.z > -1e-3) return vec2(0.0);
    vec2 o = t.xy * (z / -t.z);
    float l = length(o);
    if (l < 1e-4) return o;
    return o * (cap * tanhApprox(l / max(cap, 1e-3)) / l);
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
    vec2 g = vec2(dFdx(merged), dFdy(merged));
    vec2 outward = g / max(length(g), 1e-6);
    float inside = max(-merged, 0.0);
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
    if (glassC.x > 0.5 && alpha > 0.0) {
        float thick = 1.4 * bevel * glassC.z;
        float slope = t < 1.0 ? min(thick * rimSlope(t) / bevel, 40.0) : 0.0;
        float z = thick * rimHeight(t);
        float cap = 0.5 * bevel;
        vec2 base = pixel;
        if (near >= 0 && glassD.w > 0.0) base += (ctrs[near] - pixel) * glassD.w * 0.06 * t * onDrawer;
        vec2 q = base + refractOffset(outward, slope, iorFor(0.3014, glassC.w), z, cap);
        // In the bevel what is bent looks fairly sharp; further in, frosted
        // (any frost at all is the frosted backdrop, blurred as far as the
        // setting says: a mix of sharp and blurred would be a ghost, not a frost).
        float sharpness = smoothstep(0.0, 0.6, 1.0 - t) * 0.85;
        vec4 sq = texture(backdrop, q / res);
        vec4 fq = texture(frosted, q / res);
        vec3 behind = mix(sq.rgb / max(sq.a, 1e-3), fq.rgb / max(fq.a, 1e-3),
                          smoothstep(0.0, 0.15, glassD.x) * (1.0 - sharpness));
        float known = smoothstep(0.6, 0.98, min(sq.a, fq.a));
        if (glassC.w > 0.0 && slope > 0.01) {
            vec2 qr = base + refractOffset(outward, slope, iorFor(0.3733, glassC.w), z, cap);
            vec2 qb = base + refractOffset(outward, slope, iorFor(0.2153, glassC.w), z, cap);
            vec4 sr = texture(backdrop, qr / res);
            vec4 sb = texture(backdrop, qb / res);
            vec3 fringe = vec3(sr.r / max(sr.a, 1e-3), behind.g, sb.b / max(sb.a, 1e-3));
            behind = mix(behind, fringe, sharpness * step(0.5, min(sr.a, sb.a)));
        }
        float frost = glassD.x;
        float rawGray = dot(behind, vec3(0.299, 0.587, 0.114));
        behind = glassTone(behind, glassA.z, glassA.w, frost);
        float gray = dot(behind, vec3(0.299, 0.587, 0.114));
        vec3 vivid = clamp(mix(vec3(gray), behind, 1.18), 0.0, 1.0);
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
        float tint = clamp(glassA.y * 0.6, 0.0, 1.0);
        vec3 glassCol = mix(vivid, tone, tint);
        glassCol = mix(glassCol, tone, max(bright * 0.45, detail * 0.6) * (1.0 - 0.45 * frost));
        // The bevel, tilted away from the eye, mirrors the room round the
        // glass (Schlick, F0 = 0.04): most where it turns over at the edge.
        if (slope > 0.01) {
            float cv = 1.0 / sqrt(1.0 + slope * slope);
            float m1 = 1.0 - cv;
            float fr = 0.04 + 0.96 * m1 * m1 * m1 * m1 * m1;
            float fw = clamp(fr * 0.9, 0.0, 0.85) * smoothstep(0.0, 2.0, inside) * glassD.z;
            if (fw > 0.002) {
                vec4 env = texture(frosted, (pixel + outward * 20.0) / res);
                if (env.a > 0.5) glassCol = mix(glassCol, glassTone(env.rgb / env.a, glassA.z, glassA.w, frost), fw);
            }
        }
        float w = known * alpha;
        c = c * (1.0 - w) + vec4(glassCol, 1.0) * w;
    }
    c = over(c, vec3(1.0), clamp(shine + gleam, 0.0, 1.0) * alpha);
    fragColor = c * qt_Opacity;
}
