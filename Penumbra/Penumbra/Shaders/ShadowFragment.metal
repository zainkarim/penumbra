//
//  ShadowFragment.metal
//  Penumbra
//
//  Surface shader for the shadow disc.
//
//  Custom uniforms via material.custom.value (float4):
//    .x = shadowIntensity  [0, 1]
//    .y = innerRadius      [0, 1]
//    .z = shadowDirX       normalized XZ shadow direction, X component
//    .w = shadowDirZ       normalized XZ shadow direction, Z component
//
//  Alpha formula:
//    base  = shadowIntensity * (1 - smoothstep(innerRadius, 1.0, r))
//    dir   = mix(0.35, 1.0, (dot(radial_dir, shadowDir) + 1) / 2)
//    alpha = base * dir   (dir = 1.0 when shadowDir is zero → no directional mod)
//
//  The directional gradient makes the disc darker on the shadow side and lighter
//  on the lit side without moving any geometry, eliminating the near-arc artifact.

#include <RealityKit/RealityKit.h>

[[visible]]
void shadowSurfaceShader(realitykit::surface_parameters params)
{
    float2 uv     = params.geometry().uv0();
    float2 radial = uv * 2.0f - 1.0f;          // [-1, 1] from disc center
    float  r      = metal::length(radial);       // 0 at center, 1 at edge

    float4 custom          = params.uniforms().custom_parameter();
    float  shadowIntensity = custom.x;
    float  innerRadius     = custom.y;
    float2 shadowDir       = float2(custom.z, custom.w);

    // Radial penumbra falloff
    float alpha = shadowIntensity * (1.0f - metal::smoothstep(innerRadius, 1.0f, r));

    // Directional gradient: rotate the shadow intensity without moving geometry.
    // Guard against zero shadow direction (overhead light / off mode) and disc centre.
    float dirLen    = metal::length(shadowDir);
    float radialLen = r;   // same as metal::length(radial)
    if (dirLen > 0.001f && radialLen > 0.001f) {
        float dirDot = metal::dot(radial / radialLen, shadowDir);   // -1 … +1
        float dirMod = metal::mix(0.35f, 1.0f, (dirDot + 1.0f) * 0.5f);
        alpha *= dirMod;
    }

    alpha = metal::saturate(alpha);
    params.surface().set_emissive_color(half3(0.0h, 0.0h, 0.0h));
    params.surface().set_opacity((half)alpha);
}
