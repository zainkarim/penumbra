//
//  PlaneGrid.metal
//  Penumbra
//
//  Surface shader for the detected-plane grid overlay.
//
//  Custom uniforms via material.custom.value (float4):
//    .x = opacity    [0, 1]  (animated from 0 → 1 on plane detection)
//    .y = planeWidth  (meters) — used to keep grid cells a fixed world size
//    .z = planeDepth  (meters)
//
//  Grid cell size is fixed at 0.20 m regardless of plane extent.

#include <RealityKit/RealityKit.h>

[[visible]]
void planeGridGeometryModifier(realitykit::geometry_parameters params)
{
    // no-op: plane position is driven by the ARPlaneAnchor transform
}

[[visible]]
void planeGridSurfaceShader(realitykit::surface_parameters params)
{
    float4 custom      = params.uniforms().custom_parameter();
    float  opacity     = custom.x;
    float  planeWidth  = custom.y;
    float  planeDepth  = custom.z;

    // Map UVs [0,1] → world-space metres, then into grid cells
    float  cellSize    = 0.10;   // 10 cm cells — tight, fine grid
    float2 uv          = params.geometry().uv0();
    float2 worldUV     = uv * float2(planeWidth, planeDepth);
    float2 gridFrac    = metal::fract(worldUV / cellSize);

    // Hair-thin grid lines at cell boundaries
    float lineWidth = 0.025;
    float onLine = metal::saturate(
        metal::step(1.0 - lineWidth, gridFrac.x) +
        metal::step(1.0 - lineWidth, gridFrac.y)
    );

    float lineAlpha = onLine * 0.50;
    float fillAlpha = 0.04;
    float alpha     = metal::max(lineAlpha, fillAlpha) * opacity;

    params.surface().set_emissive_color(half3(1.0h, 1.0h, 1.0h));
    params.surface().set_opacity((half)alpha);
}
