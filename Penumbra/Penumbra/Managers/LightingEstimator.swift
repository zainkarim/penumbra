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
            lightDirection = normalize(directional.primaryLightDirection)
        } else {
            lightDirection = [0, 1, 0]
        }
    }
}
