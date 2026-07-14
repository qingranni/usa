#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 pillRefraction(
    float2 position,
    float2 size,
    float strength
) {
    float2 center = size * 0.5;
    float2 uv = (position - center) / center;

    float r = length(uv);
    float maxR = 0.85;

    if (r > maxR) {
        float edge = (r - maxR) / (1.0 - maxR);
        float warp = 1.0 + strength * edge * edge;
        float2 warped = center + uv / warp * center;
        return warped;
    }

    return position;
}
