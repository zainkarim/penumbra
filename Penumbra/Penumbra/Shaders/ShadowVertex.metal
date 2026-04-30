//
//  ShadowVertex.metal
//  Penumbra
//
//  Geometry modifier for the shadow disc mesh.
//  The disc is pre-positioned and scaled by ShadowRenderer on the CPU each frame,
//  so no per-vertex GPU projection is needed here. The geometry modifier is a
//  no-op that satisfies the CustomMaterial.Program requirement.
//
//  The radial UV coordinate (uv0) baked into the mesh drives the penumbra falloff
//  in ShadowFragment.metal:
//    uv0 = (0.5, 0.5) at disc center  → r = 0 (full shadow)
//    uv0 edge vertices at distance 0.5 from center → r = 1 (transparent)

#include <RealityKit/RealityKit.h>

[[visible]]
void shadowGeometryModifier(realitykit::geometry_parameters params)
{
    // No-op: disc position and scale are driven by CPU entity transforms.
}
