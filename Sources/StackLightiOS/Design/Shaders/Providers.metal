//
//  Providers.metal
//  StackLightiOS
//
//  Per-provider SwiftUI shader kernels. Each function is a color effect
//  (`::colorEffect`) returning a half4 colour for the given `position`.
//
//  Called from Swift via `ShaderLibrary.default.<functionName>(...)` and
//  supplied with:
//     float2  size        — view bounds in points
//     float   time        — wall-clock seconds (driven by TimelineView)
//     float4  tint        — base provider colour
//     float4  accent      — secondary provider colour
//     float4  glow        — outer-halo colour (alpha = intensity)
//     float4  statusAccent— RGBA status tint (alpha 0 means "ignore")
//     float   intensity   — 0..1 overall strength multiplier
//
//  All kernels return a soft, dense colour field meant to be blurred by
//  SwiftUI `.blur()` and then frosted by `.glassEffect()`. They therefore do
//  NOT try to look sharp — volumetric out-of-focus is the intended aesthetic.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ----- shared helpers ------------------------------------------------------

static inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Classic 2D value noise, cheap enough for a full-screen color effect.
static inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static inline float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * valueNoise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return v;
}

// Smooth radial falloff centered at `c` with radius `r`.
static inline float bloom(float2 uv, float2 c, float r) {
    float d = distance(uv, c);
    return smoothstep(r, 0.0, d);
}

// Blend the optional status accent on top of a base colour, gated by
// statusAccent.a (0 → no effect).
static inline half3 applyStatus(half3 base, float4 statusAccent, float amount) {
    half a = (half)statusAccent.a * (half)amount;
    return mix(base, (half3)statusAccent.rgb, a);
}

// Convert uniform `uv` in [0,1] into centred coords with a stable aspect.
static inline float2 centered(float2 pos, float2 size) {
    float2 uv = pos / size;
    uv = uv - 0.5;
    uv.x *= size.x / max(size.y, 1.0);
    return uv;
}

// ===========================================================================
// 0 — monoBeam (Vercel)
// Black tint with a single slow-sweeping white beam, like a phosphor trail.
// ===========================================================================
[[ stitchable ]]
half4 monoBeam(float2 pos, half4 /*color*/,
               float2 size, float time,
               float4 tint, float4 accent, float4 glow,
               float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    // Rotated coordinate so the beam runs diagonally.
    float2 p = uv - 0.5;
    float angle = 0.35 + 0.08 * sin(time * 0.25);
    float2 r = float2(cos(angle) * p.x - sin(angle) * p.y,
                      sin(angle) * p.x + cos(angle) * p.y);
    float beam = exp(-pow(r.y * 7.0, 2.0));
    float sweep = 0.5 + 0.5 * sin(time * 0.35 + r.x * 1.2);
    float core  = bloom(uv, float2(0.5 + 0.2 * sin(time * 0.2), 0.55), 0.45);

    half3 c = (half3)tint.rgb;
    c += half3(accent.rgb) * (half)(beam * sweep * 0.9 * intensity);
    c += half3(glow.rgb)   * (half)(core * 0.45 * intensity);
    c = applyStatus(c, statusAccent, 0.35);
    return half4(c, 1.0);
}

// ===========================================================================
// 1 — softBlobs (Cloudflare)
// Warm orange metaballs drifting — evokes cloud mass lit from within.
// ===========================================================================
[[ stitchable ]]
half4 softBlobs(float2 pos, half4 /*color*/,
                float2 size, float time,
                float4 tint, float4 accent, float4 glow,
                float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float t = time * 0.25;
    float b = 0.0;
    b += bloom(uv, float2(0.35 + 0.12 * sin(t),       0.45 + 0.10 * cos(t * 0.9)), 0.48);
    b += bloom(uv, float2(0.70 + 0.15 * sin(t * 1.3), 0.60 + 0.13 * cos(t * 1.1)), 0.55) * 0.9;
    b += bloom(uv, float2(0.55 + 0.20 * cos(t * 0.6), 0.35 + 0.18 * sin(t * 0.7)), 0.42) * 0.7;

    half3 c = (half3)tint.rgb * 0.5h;
    c = mix(c, half3(glow.rgb),   (half)min(b * 0.85 * intensity, 1.0));
    c = mix(c, half3(accent.rgb), (half)(pow(b, 2.5) * 0.7 * intensity));
    c = applyStatus(c, statusAccent, 0.35);
    return half4(c, 1.0);
}

// ===========================================================================
// 2 — gearShimmer (GitHub Actions)
// Indigo radial core with a slow-rotating specular arc — mechanical sheen.
// ===========================================================================
[[ stitchable ]]
half4 gearShimmer(float2 pos, half4 /*color*/,
                  float2 size, float time,
                  float4 tint, float4 accent, float4 glow,
                  float4 statusAccent, float intensity)
{
    float2 p = centered(pos, size);
    float r = length(p);
    float core = smoothstep(0.55, 0.05, r);
    // Rotating specular wedge.
    float ang = atan2(p.y, p.x) + time * 0.35;
    float wedge = pow(0.5 + 0.5 * cos(ang * 3.0), 8.0);
    float sheen = wedge * smoothstep(0.5, 0.15, r);

    half3 c = (half3)tint.rgb * 0.8h;
    c = mix(c, half3(glow.rgb),   (half)(core * 0.9 * intensity));
    c = mix(c, half3(accent.rgb), (half)(sheen * 0.75 * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 3 — diffStreaks (GitHub PRs)
// Purple diagonal streaks reminiscent of diff hunks flowing past.
// ===========================================================================
[[ stitchable ]]
half4 diffStreaks(float2 pos, half4 /*color*/,
                  float2 size, float time,
                  float4 tint, float4 accent, float4 glow,
                  float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float2 p = uv - 0.5;
    // Rotate ~30°
    float2 r = float2(0.866 * p.x - 0.5 * p.y,
                      0.5   * p.x + 0.866 * p.y);
    float bands = sin((r.y + time * 0.08) * 12.0) * 0.5 + 0.5;
    bands = pow(bands, 3.0);
    float wash  = bloom(uv, float2(0.5, 0.5 + 0.1 * sin(time * 0.4)), 0.75);

    half3 c = (half3)tint.rgb * 0.7h;
    c = mix(c, half3(glow.rgb),   (half)(wash * 0.75 * intensity));
    c = mix(c, half3(accent.rgb), (half)(bands * 0.55 * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 4 — rippleField (Netlify)
// Teal concentric ripples emanating from an off-centre pivot.
// ===========================================================================
[[ stitchable ]]
half4 rippleField(float2 pos, half4 /*color*/,
                  float2 size, float time,
                  float4 tint, float4 accent, float4 glow,
                  float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float2 p = uv - float2(0.3 + 0.05 * sin(time * 0.3), 0.6);
    float d = length(p * float2(size.x / size.y, 1.0));
    float ripple = 0.5 + 0.5 * sin(d * 18.0 - time * 1.6);
    ripple = pow(ripple, 5.0);
    float core = smoothstep(0.8, 0.0, d);

    half3 c = (half3)tint.rgb * 0.65h;
    c = mix(c, half3(glow.rgb),   (half)(core   * 0.85 * intensity));
    c = mix(c, half3(accent.rgb), (half)(ripple * 0.5  * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 5 — motionStreaks (Railway)
// Mint directional speed-lines rolling right-to-left.
// ===========================================================================
[[ stitchable ]]
half4 motionStreaks(float2 pos, half4 /*color*/,
                    float2 size, float time,
                    float4 tint, float4 accent, float4 glow,
                    float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float line = sin((uv.y + fbm(uv * 3.0 + time * 0.1) * 0.3) * 26.0
                     - uv.x * 4.0 + time * 3.0);
    line = pow(0.5 + 0.5 * line, 6.0);
    float wash = bloom(uv, float2(0.8, 0.5), 0.8);

    half3 c = (half3)tint.rgb * 0.75h;
    c = mix(c, half3(glow.rgb),   (half)(wash * 0.8 * intensity));
    c = mix(c, half3(accent.rgb), (half)(line * 0.5 * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 6 — vaporTrail (Fly.io)
// Pink vapor wisps — fbm-driven trail against a dense core.
// ===========================================================================
[[ stitchable ]]
half4 vaporTrail(float2 pos, half4 /*color*/,
                 float2 size, float time,
                 float4 tint, float4 accent, float4 glow,
                 float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float n = fbm(uv * 3.5 + float2(time * 0.25, time * 0.1));
    float trail = smoothstep(0.35, 0.85, n);
    float core  = bloom(uv, float2(0.35 + 0.05 * sin(time * 0.2), 0.55), 0.55);

    half3 c = (half3)tint.rgb * 0.7h;
    c = mix(c, half3(glow.rgb),   (half)(core  * 0.9 * intensity));
    c = mix(c, half3(accent.rgb), (half)(trail * 0.65 * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 7 — depthClouds (Xcode Cloud)
// Blue layered volumetric clouds — two fbm layers moving at different rates.
// ===========================================================================
[[ stitchable ]]
half4 depthClouds(float2 pos, half4 /*color*/,
                  float2 size, float time,
                  float4 tint, float4 accent, float4 glow,
                  float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float back  = fbm(uv * 2.5 + float2(time * 0.06, 0.0));
    float front = fbm(uv * 4.5 + float2(time * 0.18, time * 0.05));
    float vol   = smoothstep(0.3, 0.9, back * 0.6 + front * 0.6);
    float core  = bloom(uv, float2(0.5, 0.45), 0.7);

    half3 c = (half3)tint.rgb * 0.75h;
    c = mix(c, half3(glow.rgb),   (half)(core * 0.85 * intensity));
    c = mix(c, half3(accent.rgb), (half)(vol  * 0.55 * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 8 — sweepWing (TestFlight)
// Cyan sweeping trajectory — a single bright wedge crossing left to right.
// ===========================================================================
[[ stitchable ]]
half4 sweepWing(float2 pos, half4 /*color*/,
                float2 size, float time,
                float4 tint, float4 accent, float4 glow,
                float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float sweep = fract(time * 0.12);
    float head  = smoothstep(0.08, 0.0, abs(uv.x - sweep));
    float tail  = exp(-pow((sweep - uv.x) * 4.0, 2.0)) * step(uv.x, sweep);
    float alt   = sin(uv.x * 4.0 + time * 0.4) * 0.25 + 0.55;
    float band  = exp(-pow((uv.y - alt) * 6.0, 2.0));
    float core  = bloom(uv, float2(0.5, 0.5), 0.9);

    half3 c = (half3)tint.rgb * 0.7h;
    c = mix(c, half3(glow.rgb),   (half)(core * 0.8 * intensity));
    c = mix(c, half3(accent.rgb), (half)(min(head + tail * 0.6, 1.0) * band * 0.85 * intensity));
    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// 9 — errorAura (Error banner)
// Red warning aura — pulsing outer glow, slow.
// ===========================================================================
[[ stitchable ]]
half4 errorAura(float2 pos, half4 /*color*/,
                float2 size, float time,
                float4 tint, float4 accent, float4 glow,
                float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float pulse = 0.5 + 0.5 * sin(time * 1.4);
    float halo = bloom(uv, float2(0.5, 0.5), 0.65 + 0.05 * pulse);

    half3 c = (half3)tint.rgb * 0.6h;
    c = mix(c, half3(glow.rgb),   (half)(halo * (0.65 + 0.25 * pulse) * intensity));
    c = mix(c, half3(accent.rgb), (half)(pow(halo, 3.0) * 0.55 * intensity));
    return half4(c, 1.0);
}

// ===========================================================================
// 10 — neutral (fallback / empty state attract)
// Soft drifting multi-colour blobs used when we don't yet know the provider.
// ===========================================================================
[[ stitchable ]]
half4 neutral(float2 pos, half4 /*color*/,
              float2 size, float time,
              float4 tint, float4 accent, float4 glow,
              float4 statusAccent, float intensity)
{
    float2 uv = pos / size;
    float t = time * 0.15;
    float b = 0.0;
    b += bloom(uv, float2(0.3 + 0.1 * sin(t),       0.3 + 0.1 * cos(t * 0.8)), 0.55);
    b += bloom(uv, float2(0.7 + 0.1 * cos(t * 1.1), 0.6 + 0.1 * sin(t * 0.9)), 0.55) * 0.8;

    half3 c = (half3)tint.rgb * 0.8h;
    c = mix(c, half3(glow.rgb),   (half)(b * 0.6 * intensity));
    c = mix(c, half3(accent.rgb), (half)(pow(b, 3.0) * 0.5 * intensity));
    return half4(c, 1.0);
}

// ===========================================================================
// statusOrb — radial glass orb used by the StatusDot replacement.
// Doesn't need a provider tint; just the status colour + specular.
// ===========================================================================
[[ stitchable ]]
half4 statusOrb(float2 pos, half4 /*color*/,
                float2 size, float time,
                float4 statusColor,
                float intensity /* pulse 0..1 */)
{
    float2 uv = pos / size;
    float2 p  = uv - 0.5;
    float r   = length(p) * 2.0;
    if (r > 1.0) return half4(0.0, 0.0, 0.0, 0.0);

    // Sphere-like radial falloff.
    float body    = smoothstep(1.0, 0.0, r);
    float shade   = smoothstep(1.0, 0.2, r);
    float specX   = -0.28, specY = -0.28;
    float spec    = exp(-40.0 * ((p.x - specX) * (p.x - specX)
                               + (p.y - specY) * (p.y - specY)));
    float halo    = exp(-pow((r - 1.0) * 3.0, 2.0)) * intensity;

    half3 core = (half3)statusColor.rgb * (half)(0.6 + 0.4 * shade);
    half3 c    = core;
    c += half3(1.0h) * (half)(spec * 0.85);
    c += (half3)statusColor.rgb * (half)(halo * 0.5);
    half alpha = (half)(body + halo * 0.4);
    return half4(c, min(alpha, (half)1.0));
}

// ===========================================================================
// pixelBeams (Cloudflare alt)
// Warm orange "pixel-beams" — vertical columns of pixelated light rising out
// of a warm ember bed. Each column runs on its own phase/speed so the grid
// shimmers rather than marching in lockstep. The grid is intentionally coarse
// (~14 columns) so its structure survives the downstream 22pt blur.
// ===========================================================================
[[ stitchable ]]
half4 pixelBeams(float2 pos, half4 /*color*/,
                 float2 size, float time,
                 float4 tint, float4 accent, float4 glow,
                 float4 statusAccent, float intensity)
{
    const float cols = 14.0;
    float rows = max(1.0, cols * (size.y / max(size.x, 1.0)));
    float2 uv = pos / size;
    float2 cell = floor(float2(uv.x * cols, uv.y * rows));

    float seed  = hash21(float2(cell.x, 7.7));
    float phase = seed * 6.2831853;
    float speed = 0.35 + seed * 0.75;

    // Each column fills from the bottom up to `top` (0..~0.9).
    float top = 0.25 + 0.65 * (0.5 + 0.5 * sin(time * speed + phase));

    float2 cellUV = (cell + 0.5) / float2(cols, rows);
    float fillY   = 1.0 - cellUV.y;                         // 0 top .. 1 bottom
    float edge    = 1.0 - top;
    float inBeam  = smoothstep(edge - 0.02, edge + 0.02, fillY);

    // Along-beam gradient: brightest at the crest.
    float along     = clamp((fillY - edge) / max(top, 1e-3), 0.0, 1.0);
    float beamShape = pow(1.0 - along, 1.6);

    // Per-column flicker using fbm against time.
    float flick = 0.78 + 0.22 * valueNoise(float2(cell.x * 0.4, time * 1.6));

    // Horizontal per-cell softening — beams taper instead of merging.
    float colCenter = (cell.x + 0.5) / cols;
    float xDist     = abs(uv.x - colCenter) * cols;
    float xShape    = smoothstep(0.55, 0.12, xDist);

    float mask = inBeam * beamShape * flick * xShape;

    // Warm ember base — slow, breathing.
    float ember = fbm(uv * float2(3.0, 5.0) + float2(0.0, time * 0.20));
    half3 base  = (half3)tint.rgb * (half)(0.22 + 0.35 * ember);

    // Build beam colour: tint → glow → accent as mask grows.
    half3 beamCol = mix((half3)tint.rgb, (half3)glow.rgb,   (half)clamp(mask, 0.0, 1.0));
    beamCol       = mix(beamCol,         (half3)accent.rgb, (half)clamp(pow(mask, 1.8), 0.0, 1.0));

    half3 c = mix(base, beamCol, (half)clamp(mask * intensity, 0.0, 1.0));

    // Subtle row banding for retro pixel feel.
    float band = 0.94 + 0.06 * fract(cell.y * 0.5);
    c *= (half)band;

    c = applyStatus(c, statusAccent, 0.30);
    return half4(c, 1.0);
}

// ===========================================================================
// liquidDroplet — pull-to-refresh indicator.
// Renders a single elongated droplet whose length scales with `stretch`.
// ===========================================================================
[[ stitchable ]]
half4 liquidDroplet(float2 pos, half4 /*color*/,
                    float2 size, float time,
                    float4 tint, float stretch, float intensity)
{
    float2 uv = pos / size;
    float2 p  = uv - 0.5;
    // Elongate along Y by `stretch`.
    p.y /= max(stretch, 0.4);
    float r = length(p) * 2.0;
    float body = smoothstep(0.9, 0.0, r);
    float wave = 0.5 + 0.5 * sin(time * 6.0 + uv.y * 18.0);
    float spec = exp(-50.0 * ((uv.x - 0.42) * (uv.x - 0.42)
                            + (uv.y - 0.35) * (uv.y - 0.35)));

    half3 c = (half3)tint.rgb * (half)(0.8 + 0.2 * wave);
    c += half3(1.0h) * (half)(spec * 0.8);
    return half4(c, (half)(body * intensity));
}
