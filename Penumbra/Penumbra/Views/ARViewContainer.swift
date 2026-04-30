//
//  ARViewContainer.swift
//  Penumbra
//
//  Created by Zain Karim on 3/28/26.
//

import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let lightingEstimator = LightingEstimator()
        context.coordinator.lightingEstimator = lightingEstimator

        let sessionManager = ARSessionManager(arView: arView)
        sessionManager.lightingEstimator = lightingEstimator
        context.coordinator.sessionManager = sessionManager

        let sceneManager = SceneManager()
        sceneManager.arView = arView
        context.coordinator.sceneManager = sceneManager

        sessionManager.sceneManager = sceneManager

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator {
        var sessionManager: ARSessionManager?
        var sceneManager: SceneManager?
        var lightingEstimator: LightingEstimator?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            sceneManager?.handleTap(gesture)
        }
    }
}
