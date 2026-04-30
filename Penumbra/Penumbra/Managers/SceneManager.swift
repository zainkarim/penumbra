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
    var shadowRenderer: ShadowRenderer?
    private var debugArrowAnchor: AnchorEntity?

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

        let radius: Float = 0.05
        let mesh = MeshResource.generateSphere(radius: radius)
        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: nil)
        material.metallic = .float(0)
        material.roughness = .float(1)

        let sphere = ModelEntity(mesh: mesh, materials: [material])
        sphere.position.y = radius  // Sit on the plane surface
        sphere.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)

        let anchorEntity = AnchorEntity(anchor: planeAnchor)
        anchorEntity.addChild(sphere)
        arView.scene.addAnchor(anchorEntity)
        placedObjects.append(sphere)

        try? shadowRenderer?.attachShadow(to: sphere, on: anchorEntity, sphereRadius: radius)
    }

    // MARK: - Debug Arrow

    func updateDebugArrow(lightDirection: SIMD3<Float>) {
        guard let arView else { return }

        if debugArrowAnchor == nil {
            let anchor = AnchorEntity(world: SIMD3<Float>(0, 0.2, -0.5))
            anchor.addChild(makeDebugArrow())
            arView.scene.addAnchor(anchor)
            debugArrowAnchor = anchor
        }

        guard let arrow = debugArrowAnchor?.children.first else { return }
        arrow.orientation = quaternion(from: [0, 1, 0], to: lightDirection)
    }

    private func makeDebugArrow() -> Entity {
        let parent = Entity()

        let shaft = ModelEntity(
            mesh: .generateCylinder(height: 0.3, radius: 0.01),
            materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
        )
        shaft.position = [0, 0.15, 0]
        parent.addChild(shaft)

        let tip = ModelEntity(
            mesh: .generateCone(height: 0.08, radius: 0.025),
            materials: [SimpleMaterial(color: .systemOrange, isMetallic: false)]
        )
        tip.position = [0, 0.34, 0]
        parent.addChild(tip)

        return parent
    }

    // Rotates the canonical Y-axis to align with `target`. Handles antiparallel edge case.
    private func quaternion(from: SIMD3<Float>, to target: SIMD3<Float>) -> simd_quatf {
        let t = normalize(target)
        let dot = simd_dot(from, t)
        if dot > 0.9999  { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        if dot < -0.9999 { return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0)) }
        return simd_quatf(angle: acos(dot), axis: normalize(simd_cross(from, t)))
    }
}
