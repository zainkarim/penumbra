//
//  LightingEstimator.swift
//  Penumbra
//
//  Created by Zain Karim on 4/30/26.
//

import ARKit
import Observation

@Observable
@MainActor
final class LightingEstimator {

    private(set) var lightDirection: SIMD3<Float> = [0, 1, 0]
    private(set) var intensity: Float = 0.5
    private(set) var colorTemperature: Float = 6500

    private let referenceIntensity: Float = 1000.0

    func update(frame: ARFrame) {
        guard let estimate = frame.lightEstimate else { return }

        intensity = min(Float(estimate.ambientIntensity) / referenceIntensity, 1.0)
        colorTemperature = Float(estimate.ambientColorTemperature)

        // ARDirectionalLightEstimate requires environmentTexturing = .automatic
        // and is unavailable in plain/untextured environments — guard required.
        if let directional = estimate as? ARDirectionalLightEstimate {
            // primaryLightDirection appears to be in camera-local space despite docs
            // saying "world space". Rotate into world space via the camera transform.
            // w=0 applies rotation only (suppresses translation).
            let rawDir = directional.primaryLightDirection
            let rotated = frame.camera.transform * SIMD4<Float>(rawDir, 0)
            lightDirection = normalize(SIMD3<Float>(rotated.x, rotated.y, rotated.z))
        } else {
            // 45° default avoids the zero-spread shadow of straight-down [0,1,0]
            // and prevents shadow matrix degeneracy (SHADOW_MATH.md §1 gotcha).
            lightDirection = normalize(SIMD3<Float>(0.5, 1.0, 0.5))
        }
    }
}
