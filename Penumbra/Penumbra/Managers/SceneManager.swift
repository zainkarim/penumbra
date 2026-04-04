//
//  SceneManager.swift
//  Penumbra
//
//  Created by Zain Karim on 4/3/26.
//

import ARKit
import RealityKit
import UIKit
import Observation

@Observable
@MainActor
final class SceneManager {

    private(set) var placedObjects: [ModelEntity] = []

    weak var arView: ARView?

    // MARK: - Tap Handling

    func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }

        let touchLocation = gesture.location(in: arView)
        let results = arView.raycast(
            from: touchLocation,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        )

        guard let hit = results.first else { return }
        placeObject(at: hit)
    }

    // MARK: - Object Placement

    private func placeObject(at hit: ARRaycastResult) {
        guard let arView, let planeAnchor = hit.anchor else { return }

        let mesh = MeshResource.generateSphere(radius: 0.05)
        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: nil)
        material.metallic = .float(0)
        material.roughness = .float(1)

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        // Disable RealityKit built-in shadow — custom shadow mesh added in Week 4
        sphere.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)

        let anchorEntity = AnchorEntity(anchor: planeAnchor)
        anchorEntity.addChild(sphere)
        arView.scene.addAnchor(anchorEntity)

        placedObjects.append(sphere)
    }
}
