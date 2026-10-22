#version 440
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ilyamiro and the Serpantinum contributors (https://github.com/ilyamiro/serpantinum).
// Ported from Serpantinum (liquid_glass.frag, GlassFill.qml).
// See THIRD_PARTY.md.
// A card on the glass (components/GlassCard.qml): Serpantinum's nested glass,
// its liquid_glass.frag at nest level 1 in clear mode. `src` is the frame and
// drawers as drawn (ScreenScope's glassSurface), `srcRect` where the card is
// on it. The card's flat is only its tint over the drawer's glass, which
// shows through untouched; its rim is a squircle bevel that bends that glass
// by Snell's law and pulls it inwards, red and blue apart, mirrors what is
// just outside, and is lit by a hairline, a sheen and a thin spectrum; it
// swells a little under the pointer and bends harder while it moves.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 radii;       // tl, tr, br, bl
    vec4 tintColor;
    float tintAmount;
    float bezel;
    float thickness;
    float dispersion;
    float rim;
    vec4 srcRect;     // the card on src: x, y, w, h (0..1)
    vec2 cursor;      // the pointer, in the card's px
    float hover;
    float motion;
};

layout(binding = 1) uniform sampler2D src;

const float NEST = 0.5;
const vec2 lightDir = vec2(-0.55, -0.83);

float sdRoundBox(vec2 p, vec2 b, vec4 r) {
    float rad = p.x > 0.0 ? (p.y > 0.0 ? r.z : r.y) : (p.y > 0.0 ? r.w : r.x);
    rad = min(rad, min(b.x, b.y));
    vec2 q = abs(p) - b + rad;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

float sdf(vec2 p) { return sdRoundBox(p, itemSize * 0.5, radii); }

// What is under the card at p (card px from its centre), premultiplied out.
vec3 fetch(vec2 p) {
    vec2 uv = (p + itemSize * 0.5) / itemSize;
    vec4 c = texture(src, clamp(srcRect.xy + uv * srcRect.zw, vec2(0.0), vec2(1.0)));
    return c.a > 1e-3 ? c.rgb / c.a : vec3(0.0);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    float dist = sdf(p);
    if (dist > 1.0) { fragColor = vec4(0.0); return; }
    float coverage = clamp(0.5 - dist, 0.0, 1.0);

    float t = max(-dist, 0.0);
    float bz = max(bezel, 1.0) * 1.45;
    vec2 g = vec2(0.0, -1.0);
    if (t < bz + 2.0) {
        const vec2 e = vec2(0.75, 0.0);
        vec2 grad = vec2(sdf(p + e.xy) - sdf(p - e.xy), sdf(p + e.yx) - sdf(p - e.yx));
        if (length(grad) > 0.0001) g = normalize(grad);
    }

    float u = clamp(t / bz, 0.0, 1.0);
    float om = 1.0 - u;
    float om4 = om * om * om * om;
    float slope = min((om * om * om) / pow(max(1.0 - om4, 1e-3), 0.75), 7.0);
    vec2 toCursor = cursor - itemSize * 0.5 - p;
    float cd = length(toCursor);
    float reach = max(40.0, min(itemSize.x, itemSize.y) * 0.6);
    float near = hover * exp(-cd * cd / (2.0 * reach * reach));
    float sigma = reach * 0.5;
    float bulgeH = hover * exp(-cd * cd / (2.0 * sigma * sigma)) * 0.35 * (1.0 + 1.2 * motion) * thickness * (1.0 - 0.5 * NEST);
    vec3 normal = normalize(vec3(g * slope - bulgeH * toCursor / (sigma * sigma), 1.0));
    float th = thickness * 1.35 * (1.0 + 0.12 * near + 0.64 * motion);

    float edgeFall = om * om;
    float wobble = sin(dot(p, vec2(0.11, 0.09)) + t * 0.35) * 0.5 + 0.5;
    vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / 1.5);
    vec2 dG = ray.xy / max(-ray.z, 0.2) * th
        + (-g * edgeFall * bz * (0.294 + 0.11 * wobble) + vec2(-g.y, g.x) * edgeFall * bz * 0.092 * (wobble - 0.5)) * (1.0 + 0.644 * motion);
    float spread = dispersion * (0.35 + 1.2 * edgeFall) * (1.0 + 2.2 * motion);

    // A card is small: its middle is magnified a little.
    vec2 zq = p / max(itemSize * 0.5, vec2(1.0));
    float zr = clamp(length(zq), 0.0, 1.0);
    float lensK = 1.0 - smoothstep(180.0, 420.0, max(itemSize.x, itemSize.y) * 0.5);
    vec2 ps = p - p * (0.045 * (1.0 - 0.5 * NEST) + 0.064 * motion) * (1.0 - zr * zr) * lensK;

    vec3 col = fetch(ps + dG);
    if (dot(dG, dG) > 0.25) {
        col.r = fetch(ps + dG * (1.0 + spread)).r;
        col.b = fetch(ps + dG * (1.0 - spread)).b;
    }
    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));

    col *= 1.0 - (1.0 - NEST) * 0.06 * exp(-t / 6.0) * clamp(g.y, 0.0, 1.0);
    col *= 1.0 - (1.0 - NEST) * 0.025 * exp(-t / (bz * 0.45));

    vec2 cursorDir = cd > 0.001 ? toCursor / cd : normalize(lightDir);
    vec2 L = normalize(mix(normalize(lightDir), cursorDir, hover * 0.4));
    float facing = dot(g, L);
    float spec = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);
    float fres = pow(1.0 - normal.z, 1.5) * (1.0 - 0.6 * NEST);
    if (fres > 0.001) {
        vec3 env = fetch(p + g * (t + bz * 1.4)) * 1.12 + 0.03;
        col = mix(col, env, clamp(fres * 0.55 * (0.4 + 0.6 * max(facing, 0.0)), 0.0, 0.6));
    }
    col *= 1.0 - 0.16 * exp(-t / (bz * 0.55)) * max(-facing, 0.0) * (1.0 - 0.7 * NEST);

    float hair = exp(-t / 1.1);
    float wide = exp(-t / 5.0);
    float edgeHi = (hair * (0.18 + 0.78 * spec) + wide * 0.10 * (0.30 + spec)) * rim * (1.0 + 0.5 * near);
    float broad = exp(-t / (bz * 0.45)) * pow(max(facing, 0.0), 2.0) * 0.2 * rim * (1.0 + 0.5 * near);
    float mx = (t - bz * 0.5) / (bz * 0.2 + 1.0);
    float men = exp(-mx * mx) * 0.07 * (0.35 + spec) * rim;
    vec3 fringe = vec3(0.0);
    if (t < bz * 2.5) {
        float fb = (t - bz * 0.42) / (bz * 0.22 + 1.0);
        float phase = dot(g, vec2(0.7, 0.45)) * 0.9 + t / (bz * 1.6) + 0.15 * dot(p, vec2(0.004, 0.003));
        vec3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (phase + vec3(0.0, 0.33, 0.67)));
        fringe = (spectrum - 0.5) * exp(-fb * fb) * (0.04 + 0.08 * spec) * rim * (1.0 + 3.0 * motion);
    }

    // Clear: the bent picture only where it is bent (the flat would show the
    // drawer's glass as it already is), the tint everywhere.
    float tA = clamp(tintAmount * (0.7 + 0.6 * l), 0.0, 1.0);
    float lensA = smoothstep(0.0, 1.0, length(dG) * 0.5);
    vec3 premul = col * lensA * (1.0 - tA) + tintColor.rgb * tA
        + vec3(edgeHi + men + broad) + fringe + vec3(0.02 * lensA);
    float alpha = lensA * (1.0 - tA) + tA;
    premul += vec3((hash12(gl_FragCoord.xy) + hash12(gl_FragCoord.xy * 1.7 + 17.0) - 1.0) * 0.004 * (1.0 - 0.7 * NEST)) * alpha;

    float a = coverage * qt_Opacity;
    fragColor = vec4(clamp(premul, 0.0, 1.0) * a, clamp(alpha, 0.0, 1.0) * a);
}
