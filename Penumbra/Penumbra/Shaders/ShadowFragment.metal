//
//  ShadowFragment.metal
//  Penumbra
//
//  Surface shader for the shadow disc. Reads the normalized radial distance r
//  from uv0, then applies a smoothstep penumbra falloff:
//
//    alpha(r) = shadowIntensity * (1 - smoothstep(innerRadius, 1.0, r))
//
//  Custom uniforms via material.custom.value (float4):
//    .x = shadowIntensity  [0, 1]
//    .y = innerRadius      [0, 1]  (inner edge of penumbra gradient)
//
//  The material uses .unlit lighting, so set_emissive_color drives the output
//  color (black) and set_opacity drives the alpha blend.

#include <RealityKit/RealityKit.h>

[[visible]]
void shadowSurfaceShader(realitykit::surface_parameters params)
{
    // uv0: disc center = (0.5, 0.5); edge at distance 0.5 from center
    float2 uv = params.geometry().uv0();
    float2 radial = uv * 2.0 - 1.0;   // remap [0,1] -> [-1,1]
    float r = metal::length(radial);    // 0 at center, 1 at disc edge

    float4 custom = params.uniforms().custom_parameter();
    float shadowIntensity = custom.x;
    float innerRadius     = custom.y;

    // Full shadow inside innerRadius, smooth fade to transparent at r = 1.0
    float alpha = shadowIntensity * (1.0 - metal::smoothstep(innerRadius, 1.0, r));
    alpha = metal::saturate(alpha);

    // Unlit black disc; opacity carries the shadow alpha
    params.surface().set_emissive_color(half3(0.0h, 0.0h, 0.0h));
    params.surface().set_opacity((half)alpha);
}
