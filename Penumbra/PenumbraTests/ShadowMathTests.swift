//
//  ShadowMathTests.swift
//  PenumbraTests
//
//  Pure-math unit tests. No ARKit, no RealityKit — runs in simulator.

import Testing
import simd
@testable import Penumbra

struct ShadowMathTests {

    // 1. Vertical light, sphere at origin → shadow directly beneath
    @Test func shadowCenter_verticalLight_centersBelow() {
        let result = ShadowMath.shadowCenter(
            spherePos: SIMD3<Float>(0, 0.05, 0),
            lightDir: SIMD3<Float>(0, 1, 0)
        )
        #expect(abs(result.x) < 1e-4)
        #expect(abs(result.y) < 1e-4)  // y here is the z-axis component
    }

    // 2. 45° from +X → shadow offset in −X direction by ~0.05 m
    @Test func shadowCenter_45degreeFromX_offsetsNegativeX() {
        let lightDir = normalize(SIMD3<Float>(1, 1, 0))
        let result = ShadowMath.shadowCenter(
            spherePos: SIMD3<Float>(0, 0.05, 0),
            lightDir: lightDir
        )
        // t = 0.05 / L.y;  center.x = 0 - t * L.x ≈ -0.05
        #expect(abs(result.x - (-0.05)) < 1e-4)
        #expect(abs(result.y) < 1e-4)
    }

    // 3. Degenerate grazing light (L.y ≈ 0) → fallback fires, result is finite
    @Test func shadowCenter_grazingLight_producesFiniteResult() {
        let result = ShadowMath.shadowCenter(
            spherePos: SIMD3<Float>(0, 0.05, 0),
            lightDir: SIMD3<Float>(1, 0.0005, 0)
        )
        #expect(result.x.isFinite)
        #expect(result.y.isFinite)
    }

    // 4. Sphere off-centre in anchor space preserves XZ offset under vertical light
    @Test func shadowCenter_offCenterSphere_preservesXZOffset() {
        let result = ShadowMath.shadowCenter(
            spherePos: SIMD3<Float>(0.1, 0.05, -0.2),
            lightDir: SIMD3<Float>(0, 1, 0)
        )
        #expect(abs(result.x - 0.1) < 1e-4)
        #expect(abs(result.y - (-0.2)) < 1e-4)
    }

    // 5. Intensity at reference lux → 1.0
    @Test func normalizedIntensity_referenceLux_returnsOne() {
        let result = ShadowMath.normalizedIntensity(lux: 800, reference: 800)
        #expect(abs(result - 1.0) < 1e-6)
    }

    // 6. 200 lux / 800 reference → 0.25
    @Test func normalizedIntensity_dimRoom_returnsQuarter() {
        let result = ShadowMath.normalizedIntensity(lux: 200, reference: 800)
        #expect(abs(result - 0.25) < 1e-6)
    }

    // 7. Very bright environment → clamped at 1.0, not > 1
    @Test func normalizedIntensity_overbright_clampsAtOne() {
        let result = ShadowMath.normalizedIntensity(lux: 5000, reference: 800)
        #expect(result == 1.0)
    }

    // 8. Normal upward light direction passes through safeLightDirection unchanged
    @Test func safeLightDirection_verticalInput_unchanged() {
        let result = ShadowMath.safeLightDirection(SIMD3<Float>(0, 1, 0))
        #expect(abs(result.x - 0) < 1e-5)
        #expect(abs(result.y - 1) < 1e-5)
        #expect(abs(result.z - 0) < 1e-5)
    }

    // 9. Horizontal (degenerate) input → replaced with 45° fallback
    @Test func safeLightDirection_horizontal_returnsFallback() {
        let result = ShadowMath.safeLightDirection(SIMD3<Float>(1, 0, 0))
        let expected = normalize(SIMD3<Float>(0.5, 1.0, 0.5))
        #expect(abs(result.x - expected.x) < 1e-5)
        #expect(abs(result.y - expected.y) < 1e-5)
        #expect(abs(result.z - expected.z) < 1e-5)
    }
}
