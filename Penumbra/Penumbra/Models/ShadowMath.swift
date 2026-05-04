//
//  ShadowMath.swift
//  Penumbra
//
//  Pure-Swift shadow math helpers. No ARKit or RealityKit imports — callable
//  from unit tests without a device or GPU.

import simd

enum ShadowMath {

    /// Projects a sphere position onto the horizontal plane (y = 0 in anchor space)
    /// using the planar shadow formula from SHADOW_MATH.md §1.
    /// Returns (x, z) of the shadow disc centre.
    static func shadowCenter(spherePos: SIMD3<Float>, lightDir: SIMD3<Float>) -> SIMD2<Float> {
        let safeL = safeLightDirection(lightDir)
        let t = spherePos.y / safeL.y
        return SIMD2<Float>(spherePos.x - t * safeL.x, spherePos.z - t * safeL.z)
    }

    /// Maps ambient lux to a [0, 1] shadow intensity. Clamps above referenceIntensity.
    static func normalizedIntensity(lux: Float, reference: Float) -> Float {
        min(lux / reference, 1.0)
    }

    /// Returns a normalised light direction guaranteed to have |y| > 0.001.
    /// Replaces near-horizontal directions with a 45° fallback to avoid
    /// degenerate shadow projection (see HANDOFF.md Gotcha #10).
    static func safeLightDirection(_ lightDir: SIMD3<Float>) -> SIMD3<Float> {
        let L = normalize(lightDir)
        return abs(L.y) > 0.001 ? L : normalize(SIMD3<Float>(0.5, 1.0, 0.5))
    }
}
