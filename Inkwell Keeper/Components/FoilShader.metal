//
//  FoilShader.metal
//  Inkwell Keeper
//
//  Holographic foil for card art, used by `InteractiveHolographicEffect` through SwiftUI's `colorEffect`.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Cheap per-cell random number in 0..<1.
static float foilHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/// A soft iridescent palette: cyan, violet, gold, green, and back.
static float3 foilSpectrum(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (t + float3(0.0, 0.33, 0.67)));
}

/// - Parameters:
///   - size: The view's size in points.
///   - tilt: How the card is angled toward the viewer, roughly -1...1 on each axis.
///   - strength: 0 turns the effect off; 1 is full foil.
[[ stitchable ]] half4 foil(float2 position, half4 color, float2 size, float2 tilt, float strength) {
    if (color.a < 0.001h || strength <= 0.0) {
        return color;
    }

    // Centered coordinates where the shorter side spans -0.5...0.5, so bands keep the
    // same angle and width on portrait and landscape cards.
    float2 q = (position - size * 0.5) / min(size.x, size.y);

    // Diagonal rainbow bands that slide across the card as it tilts.
    float band = dot(q, float2(0.62, 0.78)) * 1.4 + tilt.x * 0.85 + tilt.y * 0.55;
    float3 rainbow = foilSpectrum(band);

    // Foil reads strongest on lighter parts of the art, like ink printed over foil.
    float3 base = float3(color.rgb) / max(float(color.a), 0.001);
    float luma = dot(base, float3(0.299, 0.587, 0.114));
    float mask = 0.3 + 0.7 * luma;

    // A soft highlight where the light catches the card, opposite the tilt.
    float2 light = -tilt * 0.55;
    float distance = length(q - light);
    float highlight = exp(-distance * distance * 5.0);

    // Glitter: a few cells hold a soft round speck that glints when the tilt sweeps
    // past its own angle.
    float2 scaled = position / 3.0;
    float seed = foilHash(floor(scaled));
    float speck = smoothstep(0.45, 0.0, length(fract(scaled) - 0.5));
    float glint = step(0.982, seed) * speck * pow(max(0.0, sin(seed * 60.0 + band * 9.0)), 10.0);

    float3 sheen = rainbow * 0.2 * mask
        + (rainbow * 0.4 + 0.6) * highlight * 0.28
        + glint * 0.9;
    float3 result = base + sheen * strength;
    return half4(half3(clamp(result, 0.0, 1.0)) * color.a, color.a);
}
