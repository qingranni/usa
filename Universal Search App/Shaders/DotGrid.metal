#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 mvp;
    float    time;
    float    gridCount;   // points per side
    float    pointSize;   // base dot size in pixels (at unit depth)
    float    amplitude;   // height of the wrinkles
    float    dismiss;     // 0 = fully visible, 1 = animated out
    float    morph;       // globe weight  (0..1)
    float    arrow;       // arrow weight  (0..1)
    // --- Playground-tunable knobs (defaults live in DotGridParams) ---
    float    waveFreq;    // primary swell frequency
    float    waveFreq2;   // secondary modulation frequency
    float    wave2Amp;    // secondary modulation amplitude
    float    coreSharp;   // core Gaussian tightness (higher = smaller dot)
    float    coreStrength;// core brightness
    float    haloSpread;  // halo Gaussian spread (lower = wider/more diffuse)
    float    haloStrength;// halo brightness
    float    bloomMin;    // sprite-size scale at troughs
    float    bloomMax;    // sprite-size scale at crests
    float    shadeMin;    // brightness at troughs
    float    shadeMax;    // brightness at crests
    float    hueWarm;     // warm push on crests (0..1)
    float    hueCool;     // cool push on troughs (0..1)
    float4   dotColor;
    float4   bgColor;
    // --- One-shot event channels (0 = inactive; driven by DotGridController) ---
    float4   shock;       // xy = origin (grid space), z = radius, w = strength
    float    flash;       // global brightness spike (0..~1.5)
    float    pulseAmp;    // global amplitude/size swell (0..~1)
    float    sweepPos;    // travelling band position in x (-2 = inactive)
    float    sweepStr;    // sweep brightness
    float    gather;      // pull dots toward centre (0..1)
    float    burst;       // explode dots outward + up (0..1)
    // --- Ripple-reveal knobs ---
    float    ambientVis;  // resting visibility of the grid (0 = invisible)
    float    revealGain;  // how strongly events (ripple) reveal dots
};

struct VertexOut {
    float4 position  [[position]];
    float  pointSize [[point_size]];
    float  height;            // surface height, for shading
    float  boost;             // per-dot momentary brightness (events)
};

// Departures-style arrow (pointing up-right, rotated 45°). Returns the signed
// "inside margin": positive inside the arrow (larger = deeper inside), negative
// outside. Used both to mask dots and to extrude the shape into 3D.
static float arrowField(float2 p) {
    // Rotate into arrow space: u = along the arrow, v = across it.
    float u = (p.x + p.y) * 0.70710678;
    float v = (p.y - p.x) * 0.70710678;

    float tip      = 0.8;    // arrow point
    float shaftEnd = -0.8;   // tail of the shaft
    float halfW    = 0.13;   // strip half-width (shaft and barbs)
    float barbLen  = 0.55;   // how far the head barbs run back from the tip

    // Shaft: a thick diagonal strip along the arrow axis (v ~ 0).
    float shaft = min(min(u - shaftEnd, tip - u), halfW - abs(v));

    // Head: two diagonal barb strips making an open chevron. They lie on the
    // lines |v| = (tip - u), i.e. ±45° from the shaft. Letting `along` go
    // slightly negative past the tip makes the two barbs converge to a sharp
    // point instead of a blunt cap.
    float along = tip - u;                       // 0 at tip, grows backward
    float barb  = halfW - abs(abs(v) - along);
    if (along > barbLen) barb = -1.0;            // limit barb length only

    return max(shaft, barb);
}

// Height field — smooth, long-wavelength crossing swells make a gently rolling
// sheet (like dunes) rather than a choppy wrinkle. The second term is a small,
// low-frequency modulation so ridges meander without adding chop.
static float surface(float2 p, float t, float amp, float f1, float f2, float a2) {
    float h = sin(p.x * f1 + t) * cos(p.y * f1 + t * 0.7);
    h += a2 * sin(p.x * f2 - t * 0.9) * sin(p.y * (f2 * 0.81) + t * 0.5);
    return h * amp;
}

// Each bump: xy = grid position the user tapped, z = age in seconds.
vertex VertexOut mesh_dots_vertex(uint vid [[vertex_id]],
                                  constant Uniforms &u    [[buffer(0)]],
                                  constant float4 *bumps  [[buffer(1)]],
                                  constant int &bumpCount [[buffer(2)]]) {
    // Animated grid count: n shrinks toward 0 as the grid is dismissed.
    // The draw call always submits maxGrid^2 vertices; any vertex beyond the
    // current n*n is culled, so the lattice actually gets coarser/sparser.
    uint  n  = max(uint(round(u.gridCount)), 1u);
    bool  culled = (vid >= n * n);
    uint  gx = vid % n;
    uint  gy = vid / n;

    // Parametric grid in [-1, 1] on the X/Z plane.
    float denom = max(float(n) - 1.0, 1.0);
    float fx = (float(gx) / denom) * 2.0 - 1.0;
    float fz = (float(gy) / denom) * 2.0 - 1.0;

    // Fade the ambient wrinkle out as it leaves the flat sheet, so the globe
    // and arrow stay undistorted (touch bumps below still apply).
    float flatness = 1.0 - clamp(u.morph + u.arrow, 0.0, 1.0);
    float y = surface(float2(fx, fz), u.time, u.amplitude,
                      u.waveFreq, u.waveFreq2, u.wave2Amp) * flatness;

    // Touch ripples: xy = grid position, z = current strength (height).
    for (int i = 0; i < bumpCount; i++) {
        float2 d    = float2(fx, fz) - bumps[i].xy;
        float  infl = exp(-dot(d, d) / (0.22 * 0.22));    // spatial falloff
        y -= bumps[i].z * infl;                            // press inward/away
    }

    // --- One-shot events (momentary, self-decaying) ---
    // Accumulate a per-dot brightness boost as events fire.
    float boost = 0.0;

    // Pulse: whole sheet swells upward and brightens briefly.
    y += u.pulseAmp * u.amplitude * 1.0;
    boost += u.pulseAmp * 0.7;

    // Shockwave: an expanding ring rolls out from the origin. A thin gaussian
    // shell at the current radius lifts the sheet and lights the ring.
    if (u.shock.w > 0.001) {
        float sd    = distance(float2(fx, fz), u.shock.xy);
        float shell = exp(-pow((sd - u.shock.z) / 0.18, 2.0));
        y     += shell * u.shock.w * 0.45;
        boost += shell * u.shock.w * 1.0;
    }

    // Sweep: a travelling band of light in x. Only lights near sweepPos.
    if (u.sweepPos > -1.9) {
        float band = exp(-pow((fx - u.sweepPos) / 0.2, 2.0));
        y     += band * u.sweepStr * u.amplitude * 0.6;
        boost += band * u.sweepStr * 1.0;
    }

    // Three shape "bases", blended by normalised weights.
    float3 flatP = float3(fx, y, fz);

    // Globe: wrap the grid onto a sphere (fx -> longitude, fz -> latitude),
    // with the wrinkle/touch height pushed along the radius.
    float  lon = fx * 3.14159265;        // -pi .. pi
    float  lat = fz * 1.57079633;        // -pi/2 .. pi/2
    float  r   = 0.425 * (1.0 + y * 0.25);
    float3 sphereP = float3(cos(lat) * sin(lon),
                            sin(lat),
                            cos(lat) * cos(lon)) * r;

    // Arrow: extruded into a 3D solid — interior rises to a flat top with a
    // short bevel at the edges. (touch bumps still apply via y).
    float  aField  = arrowField(float2(fx, fz));
    float  aHeight = clamp(aField / 0.08, 0.0, 1.0) * 0.35;
    float3 arrowP  = float3(fx, y + aHeight, fz) * 0.45;

    // Weighted blend (normalised so positions stay bounded mid-transition).
    float wGlobe = u.morph;
    float wArrow = u.arrow;
    float wFlat  = max(0.0, 1.0 - wGlobe - wArrow);
    float wSum   = max(wFlat + wGlobe + wArrow, 0.0001);
    float3 P     = (flatP * wFlat + sphereP * wGlobe + arrowP * wArrow) / wSum;

    // Gather: pull dots toward the centre (implode); release springs them back.
    P.xz *= (1.0 - u.gather * 0.85);
    P.y  += u.gather * u.amplitude * 0.6;

    // Burst: fling dots outward and up, brightening as they scatter.
    P.xz *= (1.0 + u.burst * 0.4);
    P.y  += u.burst * u.amplitude * 0.8;
    boost += u.burst * 0.7;

    float4 world = float4(P, 1.0);
    float4 clip  = u.mvp * world;

    VertexOut out;
    out.position  = clip;
    // Perspective scaling: divide by clip.w so distant dots shrink.
    float size = clamp(u.pointSize / clip.w, 2.0, 200.0);

    // Shrink dots in step with the camera fly-in. (culled is unused while
    // the count is held constant.)
    float shrink  = 1.0 - u.dismiss;

    // Arrow silhouette: dots outside the arrow shrink away as it forms.
    float inside = step(0.0, arrowField(float2(fx, fz)));
    float mask   = mix(1.0, inside, u.arrow);

    // Wave-driven bloom: raised dots swell into big soft clouds, troughs stay
    // small tight points. `h01` is the normalised height mapped to 0..1.
    float hNorm = y / max(u.amplitude, 0.0001);      // -1..1
    float h01   = clamp(hNorm * 0.5 + 0.5, 0.0, 1.0);
    float bloom = mix(u.bloomMin, u.bloomMax, smoothstep(0.0, 1.0, h01));

    // Events also swell the sprite (flash + boost) so lit dots read bigger.
    float eventSwell = 1.0 + (u.flash + boost) * 0.45;

    out.pointSize = culled ? 0.0 : size * shrink * mask * bloom * eventSwell;
    out.height    = hNorm;
    out.boost     = boost + u.flash;
    return out;
}

fragment float4 mesh_dots_fragment(VertexOut in        [[stage_in]],
                                   float2 pc           [[point_coord]],
                                   constant Uniforms &u [[buffer(0)]]) {
    // Centred sprite coord; radial distance (0 at core, 1 at sprite edge).
    float2 c = pc - float2(0.5);
    float  d = clamp(length(c) * 2.0, 0.0, 1.0);

    // White-hot core -> yellow -> orange toward the edge.
    float3 core   = float3(1.00, 1.00, 0.95);
    float3 yellow = float3(1.00, 0.80, 0.35);
    float3 orange = float3(1.00, 0.40, 0.08);

    float3 col = mix(core, yellow, smoothstep(0.0, 0.5, d));
    col        = mix(col,  orange, smoothstep(0.4, 1.0, d));

    // Hue drift with wave height: crests (raised) shift clearly warmer toward
    // orange-red, troughs cool toward gold. `in.height` is normalised -1..1.
    float  warm      = clamp(in.height, -1.0, 1.0);
    float3 hotColor  = float3(1.00, 0.32, 0.04);   // deep warm ember
    float3 coolColor = float3(1.00, 0.86, 0.46);   // cool gold
    col = mix(col, hotColor,  clamp(warm,  0.0, 1.0) * u.hueWarm);
    col = mix(col, coolColor, clamp(-warm, 0.0, 1.0) * u.hueCool);

    // Glow: Gaussian falloffs give a smooth, ambient diffuse bloom that fades
    // continuously to nothing — no hard-edged disc. A tight core forms the
    // actual dot; a wide, faint Gaussian is the soft halo around it.
    float hot  = exp(-d * d * u.coreSharp) * u.coreStrength;  // tight core
    float halo = exp(-d * d * u.haloSpread) * u.haloStrength; // ambient bloom
    // Feather the outer edge so the square sprite boundary never shows.
    float edge = smoothstep(1.0, 0.55, d);
    halo *= edge;

    float glow = hot + halo;

    // Crests bloom bright; troughs fall almost to black — this heavy contrast
    // (driven by the wave height) is what makes raised dots read as glowing
    // clouds while the rest stay as faint pinpoints.
    float h01       = clamp(in.height * 0.5 + 0.5, 0.0, 1.0);
    float baseShade = mix(u.shadeMin, u.shadeMax, smoothstep(0.0, 1.0, h01));
    // Ambient visibility: 0 => grid hidden until a ripple/event reveals it.
    float ambient   = baseShade * u.ambientVis;
    // Ripple + events additively reveal the dots they touch.
    float shade     = ambient + baseShade * in.boost * u.revealGain;
    col    = mix(col, float3(1.0, 0.95, 0.85), clamp(in.boost * 0.35, 0.0, 0.5));

    // Pre-multiplied colour for pure additive blending.
    return float4(col * glow * shade, glow * shade);
}
